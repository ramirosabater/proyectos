// Corre en Netlify, no en el navegador — por eso ANTHROPIC_API_KEY nunca
// llega al cliente. El navegador le manda el texto del prompt más su
// token de sesión de Supabase; esta función confirma que el token
// corresponde a un usuario logueado de verdad antes de gastar la key de
// Anthropic, y solo entonces llama a Claude y devuelve el texto.
//
// Variables de entorno que necesita (Netlify → Site configuration →
// Environment variables — NO en el código, NO en el repo):
//   SUPABASE_URL          (la misma URL que ya usás en Cartera Viva)
//   SUPABASE_ANON_KEY      (la misma anon key)
//   ANTHROPIC_API_KEY      (tu key de console.anthropic.com — distinta a
//                           la que tenías filtrada antes; si es la vieja,
//                           rotala primero)

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: JSON.stringify({ error: 'method_not_allowed' }) };
  }

  const authHeader = event.headers.authorization || event.headers.Authorization || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!token) {
    return { statusCode: 401, body: JSON.stringify({ error: 'unauthorized' }) };
  }

  const { SUPABASE_URL, SUPABASE_ANON_KEY, ANTHROPIC_API_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !ANTHROPIC_API_KEY) {
    return { statusCode: 500, body: JSON.stringify({ error: 'server_misconfigured' }) };
  }

  // Confirmar que el token es de un usuario real logueado en Supabase Auth
  // (no cualquiera que le pegue directo a esta función con un token inventado).
  let userCheck;
  try {
    userCheck = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { Authorization: `Bearer ${token}`, apikey: SUPABASE_ANON_KEY },
    });
  } catch (e) {
    return { statusCode: 502, body: JSON.stringify({ error: 'auth_check_failed' }) };
  }
  if (!userCheck.ok) {
    return { statusCode: 401, body: JSON.stringify({ error: 'unauthorized' }) };
  }

  let body;
  try {
    body = JSON.parse(event.body || '{}');
  } catch {
    return { statusCode: 400, body: JSON.stringify({ error: 'bad_request' }) };
  }
  const prompt = body.prompt;
  if (!prompt || typeof prompt !== 'string' || prompt.length > 20000) {
    return { statusCode: 400, body: JSON.stringify({ error: 'bad_request' }) };
  }

  let resp;
  try {
    resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 1500,
        messages: [{ role: 'user', content: prompt }],
      }),
    });
  } catch (e) {
    return { statusCode: 502, body: JSON.stringify({ error: 'upstream_unreachable' }) };
  }

  if (!resp.ok) {
    const errText = await resp.text().catch(() => '');
    return { statusCode: 502, body: JSON.stringify({ error: 'upstream_error', detail: errText.slice(0, 500) }) };
  }

  const data = await resp.json();
  const text = (data.content || [])
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join('\n');

  if (!text) {
    return { statusCode: 502, body: JSON.stringify({ error: 'empty_completion' }) };
  }

  return {
    statusCode: 200,
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ text }),
  };
};
