// Endpoint PÚBLICO — a propósito no pide login, porque lo abre el cliente
// final. La seguridad acá no es "quién sos" sino "tenés el token exacto":
// solo alguien con el link puede ver esa propuesta puntual, ninguna otra.
//
// Usa SUPABASE_SERVICE_ROLE_KEY (distinta de la anon key — se consigue en
// Supabase → Project Settings → API → "service_role", marcada como
// secreta) para leer sin pasar por el login. Esta key NUNCA va al
// navegador ni al código del frontend — vive solo acá, como variable de
// entorno de esta función.

exports.handler = async (event) => {
  const token = (event.queryStringParameters || {}).token;
  if (!token) {
    return { statusCode: 400, body: JSON.stringify({ error: 'falta_token' }) };
  }

  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return { statusCode: 500, body: JSON.stringify({ error: 'server_misconfigured' }) };
  }
  const headers = { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` };

  try {
    const shareResp = await fetch(
      `${SUPABASE_URL}/rest/v1/shares?id=eq.${encodeURIComponent(token)}&select=propuesta_id`,
      { headers }
    );
    if (!shareResp.ok) throw new Error('share_lookup_failed');
    const shares = await shareResp.json();
    if (!shares.length) {
      return { statusCode: 404, body: JSON.stringify({ error: 'link_no_encontrado' }) };
    }

    const propResp = await fetch(
      `${SUPABASE_URL}/rest/v1/propuestas?id=eq.${encodeURIComponent(shares[0].propuesta_id)}&select=cliente_texto,contenido,gantt,creado_at,estado`,
      { headers }
    );
    if (!propResp.ok) throw new Error('propuesta_lookup_failed');
    const props = await propResp.json();
    if (!props.length) {
      return { statusCode: 404, body: JSON.stringify({ error: 'propuesta_no_encontrada' }) };
    }

    let marca = {};
    try {
      const confResp = await fetch(`${SUPABASE_URL}/rest/v1/configuracion?id=eq.1&select=nombre_negocio,logo_base64`, { headers });
      if (confResp.ok) {
        const conf = await confResp.json();
        if (conf.length) marca = conf[0];
      }
    } catch {} // la marca es opcional — si falla, seguimos sin ella

    return {
      statusCode: 200,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ ...props[0], marca }),
    };
  } catch (e) {
    return { statusCode: 502, body: JSON.stringify({ error: 'upstream_error' }) };
  }
};
