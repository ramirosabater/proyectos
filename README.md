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

## 7. Compartir propuestas con el cliente (opcional)

Para que el botón "Compartir con el cliente" funcione, hace falta un paso
más de configuración — usa una key distinta a la anon key, así que no
alcanza con lo del paso 5.

1. Corré `supabase_migracion_shares.sql` en el SQL Editor.
2. Dashboard de Supabase → Project Settings → API → copiá la key
   **`service_role`** (no la `anon` — está marcada como secreta, con un
   botón de "reveal"/"mostrar").
3. En Netlify → Site configuration → Environment variables, agregá:

| Variable | Valor |
|---|---|
| `SUPABASE_SERVICE_ROLE_KEY` | la key del paso anterior |

4. Redeploy (Deploys → Trigger deploy).

**Importante sobre esta key**: a diferencia de la anon key, la
`service_role` se salta todos los permisos (RLS) — por eso vive *solo*
como variable de entorno de la función `ver-propuesta.js`, nunca en
`index.html` ni en ningún archivo que se suba al navegador. Si alguna vez
sospechás que se filtró, se rota desde el mismo lugar donde la copiaste.

El botón "Compartir" genera un link único por propuesta (`/ver.html?token=...`)
que cualquiera con ese link puede ver, sin loguearse — pensado para
mandárselo al cliente. "Abrir borrador de mail" simplemente te arma el
mail en tu propio cliente de correo (Gmail, Outlook, lo que tengas
configurado como default) con el link ya pegado — no manda nada solo, así
no hace falta contratar ningún servicio de envío de mails para esto.

## 8. Subir archivos a la base de conocimiento

La pestaña Conocimiento acepta PDF y Word (`.docx`) — al elegir un
archivo, se extrae el texto en el propio navegador (con `pdf.js` para PDF
y `mammoth` para `.docx`, cargados desde jsdelivr, no hace falta instalar
nada) y lo deja precargado en el campo de contenido para que lo revises
antes de guardar. El `.doc` viejo (formato binario, no `.docx`) no se
puede leer así — o lo convertís a `.docx`/PDF primero, o pegás el texto a
mano. Un PDF escaneado (solo imagen, sin texto real) tampoco va a andar,
porque no hace OCR.


## 9. Todo lo nuevo: aceptación del cliente, edición, marca, seguimiento, métricas y adjuntos

Correr estas tres migraciones (en cualquier orden, las tres son independientes):

- `supabase_migracion_estado.sql` — agrega si la propuesta fue aceptada por el cliente.
- `supabase_migracion_configuracion.sql` — tu marca (nombre, logo) y tarifa por hora.
- `supabase_migracion_archivos.sql` — crea el bucket de Storage para adjuntos.

Y subir el nuevo `netlify/functions/aceptar-propuesta.js` junto con el resto (usa las mismas variables de entorno del paso 7 — `SUPABASE_SERVICE_ROLE_KEY` — así que si ya configuraste "Compartir", esto no necesita nada adicional).

Qué hace cada cosa:
- **Aceptar propuesta**: el cliente ve un botón "Acepto la propuesta" en el link que le mandaste (`ver.html`). Al tocarlo, queda marcada como aceptada — lo vas a ver como una tildecita verde en el historial y en Proyectos, y entra en la métrica de "aceptadas".
- **Editar texto**: en cualquier propuesta, botón "Editar texto" — todo el contenido se vuelve editable, incluida una calculadora de inversión (monto fijo, o horas × tu tarifa) para que el link que le mandás al cliente ya lleve un presupuesto real en vez de "a definir".
- **Ajustes → marca**: cargá tu nombre de consultora/logo y tu tarifa por hora una sola vez (pestaña Ajustes). Aparece en el link público y en el PDF descargado; la tarifa precarga la calculadora de inversión.
- **Panel de seguimiento**: en Proyectos, si algún cliente no tiene actividad hace más de 15 días, aparece un aviso arriba de la lista.
- **Métricas**: contador de propuestas del mes, aceptadas totales y el tema más frecuente, arriba de Proyectos.
- **Archivos adjuntos**: dentro del detalle de cada proyecto, subís fotos/planos/capturas — quedan en un bucket privado de Supabase Storage, solo vos (logueado) podés verlos o bajarlos.

## 10. Subprocesos dentro de cada tema

Corré `supabase_migracion_subprocesos.sql`. Reorganiza el banco de
preguntas: cada tema madre (Facturación, RRHH, etc.) pasa a tener
subprocesos (por ejemplo, Facturación → "Emisión de facturas" y "Control
y sistemas"), y **todas las preguntas que ya tenías cargadas se reasignan
solas** al subproceso que les corresponde — no se pierde ninguna. Si
habías agregado preguntas propias que no matchean ningún texto original,
quedan agrupadas en un subproceso "General" para que no se pierdan de
vista, y las podés mover mejor a mano después (borrarla y volver a
cargarla en el subproceso correcto).

Después de correr la migración, reemplazá `public/index.html` y
redeployá — en el Banco de preguntas, al elegir un tema ahora aparece una
fila de subprocesos abajo del nombre, y las preguntas se agregan/borran
dentro del subproceso seleccionado, no sueltas en el tema.

## 11. Opciones de pago y Tablero de control

Corré `supabase_migracion_pagos.sql`. Reemplazá `public/index.html` y redeployá.

- **Opciones de pago**: en "Editar texto" de cualquier propuesta, el modo
  "Opciones de pago" de la calculadora de Inversión te deja cargar un
  monto base, un % de descuento por pago único, y una cantidad de cuotas
  con su % de interés — arma el texto con las dos opciones para el
  cliente.
- **Cobros**: dentro de cada propuesta, una sección nueva "Cobros" donde
  cargás cada pago esperado (descripción + monto) y los vas marcando
  cobrado/pendiente a medida que entran.
- **Tablero**: pestaña nueva. Muestra el total facturable estimado, lo
  cobrado, lo pendiente y cuántas propuestas están aceptadas; abajo, el
  avance por proyecto (cobrado vs. total) y la lista de cobros pendientes
  sin resolver.

## 12. La herramienta aprende sola (septiembre 2026)

Corré `supabase_migracion_aprendizaje.sql` (y `supabase_migracion_pagos.sql`
si nunca lo corriste: antes faltaba en el proyecto). Reemplazá
`public/index.html` y `netlify/functions/generar-propuesta.js` y redeployá.
No hacen falta variables de entorno nuevas.

- **Después de la reunión**: al generar una propuesta, aparece un panel
  nuevo abajo con dos cosas:
  - *Quedaron sin responder*: lo que falta saber para cerrar la
    propuesta, redactado para mandárselo al cliente. "Armar mail de
    seguimiento" te abre el borrador en tu correo con las preguntas ya
    puestas.
  - *Preguntas nuevas para el banco*: hasta 3 preguntas que esta reunión
    mostró que te faltaban, cada una con su subproceso. "Agregar al banco"
    la suma directo; "Descartar" la saca de la lista.
  Este panel es solo tuyo: el link que ve el cliente no lo muestra. En
  propuestas viejas aparece el botón "Analizar reunión" para correrlo.
- **Casos aceptados → Conocimiento**: cuando una propuesta pasa a
  aceptada, se guarda sola en la pestaña Conocimiento un resumen del caso
  (dolor, solución, inversión, semanas y criterios de éxito). Las próximas
  propuestas de ese tema lo usan para calibrar plazos y montos. Si un
  resumen no te sirve, lo borrás desde Conocimiento como cualquier otro.
- **Reuniones largas**: el límite de texto subió de 20.000 a ~150.000
  caracteres, y los errores ahora dicen qué pasó (notas muy largas, sesión
  vencida, tiempo agotado) en vez de un mensaje genérico.

Nota: las copias viejas de `index.html`, `ver.html` y las funciones que
estaban sueltas en la raíz del proyecto se borraron. Netlify solo usa las
de `public/` y `netlify/functions/`.

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
