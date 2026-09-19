# Cuaderno de relevamiento — despliegue en Netlify + Supabase

App standalone (ya no depende de claude.ai): banco de preguntas por tema +
generador de propuesta de 7 secciones a partir de las notas de la reunión
(las que te arme Gemini, pegadas a mano). Login propio, datos en el mismo
Supabase de Cartera Viva.

## 1. Correr la migración SQL

En el dashboard de Supabase (el mismo proyecto de Cartera Viva) → **SQL
Editor** → **New query** → pegar el contenido de `supabase_migracion.sql`
→ **Run**.

Esto crea las tablas `temas`, `preguntas` y `propuestas`, las deja
protegidas por login (nadie sin sesión puede leer ni escribir), y carga
los 5 temas de arranque con sus preguntas.

Si tu tabla `proyectos` no tiene una columna `id` de tipo `uuid`, editá la
línea `references proyectos(id)` antes de correr el script — si no, esa
parte va a fallar (las tablas nuevas igual se crean, pero sin el link a
proyectos).

## 2. Crear tu usuario de login

Dashboard de Supabase → **Authentication** → **Users** → **Add user** →
completá tu email y una contraseña. Con eso alcanza — no hace falta que
te mandes ningún mail de confirmación.

Después, en **Authentication → Providers → Email**, desactivá "Allow new
users to sign up" — así nadie más puede crearse una cuenta sola, aunque
tenga el link de la app (no hay pantalla de registro en la app igual,
pero esto cierra la puerta del todo).

## 3. Completar la config del frontend

Abrí `public/index.html`, buscá el bloque `CONFIGURACIÓN` cerca del
principio y completá:

```js
const SUPABASE_URL = "https://tu-proyecto.supabase.co";
const SUPABASE_ANON_KEY = "tu-anon-key";
```

Son las mismas que ya usás en Cartera Viva (Dashboard → Project Settings
→ API). Estos dos valores son seguros de dejar visibles en el código —
Supabase los protege con las políticas de seguridad que corrió el SQL del
paso 1, no ocultándolos.

**La clave de Anthropic NO va acá** — ver paso 5.

## 4. Desplegar en Netlify

Opción más simple, sin usar consola ni git:

1. Entrá a [app.netlify.com](https://app.netlify.com) → creá cuenta si no
   tenés.
2. "Add new site" → "Deploy manually".
3. Arrastrá la carpeta **completa** del proyecto (`relevamiento-app/`,
   la que tiene `netlify.toml`, `public/` y `netlify/` adentro) a la zona
   de drop.

Netlify va a leer `netlify.toml`, publicar lo que está en `public/` y
desplegar la función de `netlify/functions/` automáticamente.

(Si más adelante querés que se actualice solo cada vez que cambiás algo,
conviene pasar a "Deploy from Git" con un repo en GitHub en vez de arrastrar
la carpeta cada vez — pero para arrancar, deploy manual alcanza.)

## 5. Configurar la clave de Anthropic (server-side, nunca en el código)

En el sitio ya creado en Netlify → **Site configuration** → **Environment
variables** → **Add a variable**, y cargá estas tres:

| Variable | Valor |
|---|---|
| `ANTHROPIC_API_KEY` | tu key de console.anthropic.com |
| `SUPABASE_URL` | la misma URL del paso 3 |
| `SUPABASE_ANON_KEY` | la misma anon key del paso 3 |

Después de guardarlas, hace falta un **redeploy** para que la función las
tome (Deploys → Trigger deploy → Deploy site).

## 6. Probar

Entrá a la URL que te dio Netlify (algo como `tu-sitio.netlify.app`),
logueate con el usuario del paso 2, y probá:
- Que el banco de preguntas cargue los 5 temas de arranque.
- Agregar una pregunta nueva y que quede guardada al recargar la página.
- Pegar unas notas de prueba y generar una propuesta.

## Notas de seguridad

- La clave de Anthropic vive **solo** como variable de entorno de la
  función de Netlify — nunca llega al navegador. La función
  (`netlify/functions/generar-propuesta.js`) además verifica que quien la
  llama tenga una sesión válida de Supabase antes de gastar la key, así
  que aunque alguien encuentre la URL de la función no puede usarla sin
  loguearse primero.
- Si en algún momento vas a compartir el link del sitio con alguien más,
  acordate: cualquiera con usuario y contraseña puede generar propuestas
  (gastando tu cuota de Anthropic) y ver/editar el banco de preguntas y
  el historial completo — no hay separación por usuario. Para un solo
  consultor está bien; si sumás gente, avisame y separamos permisos por
  usuario.
