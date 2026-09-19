-- Migración: banco de preguntas por tema + propuestas generadas.
-- Correr esto en el SQL Editor de tu proyecto de Supabase (el mismo de
-- Cartera Viva) — Dashboard → SQL Editor → New query → pegar → Run.
--
-- Asume que ya existe una tabla `proyectos` con `id uuid primary key`
-- (la que ya usa Cartera Viva). Si tu columna se llama distinto o no es
-- uuid, ajustá la línea de `references proyectos(id)` antes de correr esto.

create extension if not exists "pgcrypto"; -- para gen_random_uuid()

-- ---------- temas y preguntas ----------

create table if not exists temas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  slug text unique not null,
  creado_at timestamptz not null default now()
);

create table if not exists preguntas (
  id uuid primary key default gen_random_uuid(),
  tema_id uuid not null references temas(id) on delete cascade,
  texto text not null,
  orden int not null default 0,
  creado_at timestamptz not null default now()
);

-- ---------- propuestas generadas ----------

create table if not exists propuestas (
  id uuid primary key default gen_random_uuid(),
  -- si el cliente ya existe como proyecto en Cartera Viva, se linkea acá;
  -- si no, queda null y el nombre libre se guarda en cliente_texto.
  proyecto_id uuid references proyectos(id) on delete set null,
  cliente_texto text,
  tema_id uuid references temas(id) on delete set null,
  notas text,
  contenido text not null,
  creado_por uuid references auth.users(id),
  creado_at timestamptz not null default now()
);

-- ---------- seguridad: solo usuarios logueados (Supabase Auth) ----------
-- A diferencia del resto de Cartera Viva (que usa la key anon libremente),
-- estas tres tablas quedan atrás de login: sin sesión, no se lee ni se
-- escribe nada. Como es un solo consultor usando la herramienta, cualquier
-- usuario autenticado tiene acceso completo (no hay filtro por dueño).

alter table temas enable row level security;
alter table preguntas enable row level security;
alter table propuestas enable row level security;

create policy "autenticados_leen_temas" on temas
  for select using (auth.role() = 'authenticated');
create policy "autenticados_escriben_temas" on temas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "autenticados_leen_preguntas" on preguntas
  for select using (auth.role() = 'authenticated');
create policy "autenticados_escriben_preguntas" on preguntas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "autenticados_leen_propuestas" on propuestas
  for select using (auth.role() = 'authenticated');
create policy "autenticados_escriben_propuestas" on propuestas
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ---------- banco de preguntas inicial ----------

insert into temas (nombre, slug) values
  ('Facturación', 'facturacion'),
  ('Stock y logística', 'stock-y-logistica'),
  ('Atención al cliente', 'atencion-al-cliente'),
  ('RRHH', 'rrhh'),
  ('Producción y operaciones', 'produccion-y-operaciones')
on conflict (slug) do nothing;

insert into preguntas (tema_id, texto, orden)
select t.id, q.texto, q.orden
from temas t
join (values
  ('facturacion', '¿Cómo facturan hoy — a mano, con algún sistema, con planillas?', 1),
  ('facturacion', '¿Cuántas facturas emiten por semana o por mes, aproximadamente?', 2),
  ('facturacion', '¿Cuánto tiempo les lleva armar y emitir una factura, en promedio?', 3),
  ('facturacion', '¿Quién factura hoy — una persona, varias, es parte de otra tarea?', 4),
  ('facturacion', '¿Se les pierden o duplican comprobantes alguna vez? ¿Con qué frecuencia?', 5),
  ('facturacion', '¿La facturación está conectada con stock/pedidos, o son sistemas separados?', 6),
  ('facturacion', '¿Usan algún ERP o sistema contable? ¿Cuál?', 7),
  ('facturacion', '¿Cuánto les cuesta hoy (en horas o en plata) todo el proceso de facturación por mes?', 8),
  ('stock-y-logistica', '¿Cómo controlan el stock hoy — planilla, sistema, a ojo?', 1),
  ('stock-y-logistica', '¿Con qué frecuencia hacen recuento físico y cuánto tarda?', 2),
  ('stock-y-logistica', '¿Les pasó quedarse sin stock de algo que vendían seguido? ¿Cada cuánto?', 3),
  ('stock-y-logistica', '¿Cómo deciden cuánto reponer y cuándo?', 4),
  ('stock-y-logistica', '¿Cuántos depósitos o puntos de stock manejan?', 5),
  ('stock-y-logistica', '¿El stock está conectado con las ventas/facturación en tiempo real?', 6),
  ('stock-y-logistica', '¿Quién es responsable del stock hoy?', 7),
  ('atencion-al-cliente', '¿Por dónde entran las consultas de clientes hoy — WhatsApp, teléfono, mail, redes?', 1),
  ('atencion-al-cliente', '¿Cuántas consultas reciben por día/semana, aproximadamente?', 2),
  ('atencion-al-cliente', '¿Cuánto tardan en responder en promedio?', 3),
  ('atencion-al-cliente', '¿Hay preguntas que se repiten mucho y siempre se responden igual?', 4),
  ('atencion-al-cliente', '¿Quién atiende hoy — una persona dedicada, se reparte entre varios?', 5),
  ('atencion-al-cliente', '¿Pierden consultas o se demoran en responder fuera de horario?', 6),
  ('atencion-al-cliente', '¿Miden en algo la satisfacción del cliente o los tiempos de respuesta?', 7),
  ('rrhh', '¿Cómo gestionan hoy legajos, licencias y asistencia?', 1),
  ('rrhh', '¿Cómo es el proceso de liquidación de sueldos — interno, tercerizado, con qué herramienta?', 2),
  ('rrhh', '¿Cuánto tiempo insume el proceso de liquidación por mes?', 3),
  ('rrhh', '¿Cómo reclutan y seleccionan gente nueva hoy?', 4),
  ('rrhh', '¿Tienen rotación alta en algún puesto? ¿Por qué, si lo saben?', 5),
  ('rrhh', '¿Hay algo del proceso de RRHH que hoy se hace todo en papel o en planillas sueltas?', 6),
  ('produccion-y-operaciones', '¿Cómo planifican la producción hoy — por pedido, por stock, mixto?', 1),
  ('produccion-y-operaciones', '¿Cómo registran lo que se produce — a mano, planilla, sistema?', 2),
  ('produccion-y-operaciones', '¿Cuál es el cuello de botella más claro del proceso hoy?', 3),
  ('produccion-y-operaciones', '¿Miden tiempos de producción o de entrega? ¿Cómo?', 4),
  ('produccion-y-operaciones', '¿Tienen mermas o reprocesos frecuentes? ¿Se registran de alguna forma?', 5),
  ('produccion-y-operaciones', '¿Cuántas personas están involucradas en el proceso productivo?', 6)
) as q(slug, texto, orden) on q.slug = t.slug
where not exists (
  select 1 from preguntas p where p.tema_id = t.id and p.texto = q.texto
);
