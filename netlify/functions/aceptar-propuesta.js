// Público a propósito, igual que ver-propuesta.js — el cliente no está
// logueado. La validación es "tenés el token exacto de esta propuesta",
// no login. Usa la service_role key del lado del servidor para poder
// escribir sin pasar por el RLS (que exige estar autenticado).

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: JSON.stringify({ error: 'method_not_allowed' }) };
  }
  let body;
  try { body = JSON.parse(event.body || '{}'); } catch { return { statusCode: 400, body: JSON.stringify({ error: 'bad_request' }) }; }
  const token = body.token;
  if (!token) return { statusCode: 400, body: JSON.stringify({ error: 'falta_token' }) };

  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return { statusCode: 500, body: JSON.stringify({ error: 'server_misconfigured' }) };
  }
  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    'content-type': 'application/json',
  };

  try {
    const shareResp = await fetch(`${SUPABASE_URL}/rest/v1/shares?id=eq.${encodeURIComponent(token)}&select=propuesta_id`, { headers });
    if (!shareResp.ok) throw new Error('share_lookup_failed');
    const shares = await shareResp.json();
    if (!shares.length) return { statusCode: 404, body: JSON.stringify({ error: 'link_no_encontrado' }) };

    const updResp = await fetch(`${SUPABASE_URL}/rest/v1/propuestas?id=eq.${encodeURIComponent(shares[0].propuesta_id)}`, {
      method: 'PATCH',
      headers: { ...headers, Prefer: 'return=minimal' },
      body: JSON.stringify({ estado: 'aceptada', aceptado_at: new Date().toISOString() }),
    });
    if (!updResp.ok) throw new Error('update_failed');

    return { statusCode: 200, headers: { 'content-type': 'application/json' }, body: JSON.stringify({ ok: true }) };
  } catch (e) {
    return { statusCode: 502, body: JSON.stringify({ error: 'upstream_error' }) };
  }
};
