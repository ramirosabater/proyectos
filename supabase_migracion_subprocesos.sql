-- Subprocesos: cada tema madre se divide en subprocesos, y las
-- preguntas existentes se reorganizan bajo el subproceso que les
-- corresponde (no se pierde ninguna pregunta ya cargada).

create table if not exists subprocesos (
  id uuid primary key default gen_random_uuid(),
  tema_id uuid not null references temas(id) on delete cascade,
  nombre text not null,
  slug text not null,
  orden int not null default 0,
  creado_at timestamptz not null default now(),
  unique (tema_id, slug)
);

alter table subprocesos enable row level security;
create policy "autenticados_leen_subprocesos" on subprocesos for select using (auth.role() = 'authenticated');
create policy "autenticados_escriben_subprocesos" on subprocesos for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

alter table preguntas add column if not exists subproceso_id uuid references subprocesos(id) on delete cascade;

-- subprocesos por tema
insert into subprocesos (tema_id, nombre, slug, orden)
select t.id, s.nombre, s.slug, s.orden
from temas t
join (values
  ('facturacion', 'Emisión de facturas', 'emision-de-facturas', 1),
  ('facturacion', 'Control y sistemas', 'control-y-sistemas', 2),
  ('stock-y-logistica', 'Control de inventario', 'control-de-inventario', 1),
  ('stock-y-logistica', 'Reposición y gestión', 'reposicion-y-gestion', 2),
  ('atencion-al-cliente', 'Canales y volumen', 'canales-y-volumen', 1),
  ('atencion-al-cliente', 'Calidad de atención', 'calidad-de-atencion', 2),
  ('rrhh', 'Administración de personal', 'administracion-de-personal', 1),
  ('rrhh', 'Reclutamiento y retención', 'reclutamiento-y-retencion', 2),
  ('produccion-y-operaciones', 'Planificación y registro', 'planificacion-y-registro', 1),
  ('produccion-y-operaciones', 'Eficiencia y calidad de proceso', 'eficiencia-y-calidad', 2),
  ('finanzas-y-costos', 'Control financiero', 'control-financiero', 1),
  ('finanzas-y-costos', 'Costeo y planificación', 'costeo-y-planificacion', 2),
  ('compras-y-proveedores', 'Gestión de proveedores', 'gestion-de-proveedores', 1),
  ('compras-y-proveedores', 'Seguimiento de pedidos', 'seguimiento-de-pedidos', 2),
  ('ventas-y-comercial', 'Proceso comercial', 'proceso-comercial', 1),
  ('ventas-y-comercial', 'Gestión de oportunidades', 'gestion-de-oportunidades', 2),
  ('marketing-y-redes', 'Canales y comunicación', 'canales-y-comunicacion', 1),
  ('marketing-y-redes', 'Medición y presupuesto', 'medicion-y-presupuesto', 2),
  ('tecnologia-e-infraestructura-it', 'Sistemas', 'sistemas', 1),
  ('tecnologia-e-infraestructura-it', 'Soporte y continuidad', 'soporte-y-continuidad', 2),
  ('calidad', 'Estándares', 'estandares', 1),
  ('calidad', 'Detección y registro', 'deteccion-y-registro', 2),
  ('mantenimiento', 'Tipo de mantenimiento', 'tipo-de-mantenimiento', 1),
  ('mantenimiento', 'Registro e impacto', 'registro-e-impacto', 2),
  ('legal-y-compliance', 'Documentación', 'documentacion', 1),
  ('legal-y-compliance', 'Riesgo y asesoría', 'riesgo-y-asesoria', 2),
  ('administracion-general', 'Organización', 'organizacion', 1),
  ('administracion-general', 'Procesos y documentación', 'procesos-y-documentacion', 2)
) as s(tema_slug, nombre, slug, orden) on s.tema_slug = t.slug
on conflict (tema_id, slug) do nothing;

-- reasignar cada pregunta existente a su subproceso
with mapeo(tema_slug, subproceso_slug, texto) as (
  values
    ('facturacion', 'emision-de-facturas', '¿Cómo facturan hoy — a mano, con algún sistema, con planillas?'),
    ('facturacion', 'emision-de-facturas', '¿Cuántas facturas emiten por semana o por mes, aproximadamente?'),
    ('facturacion', 'emision-de-facturas', '¿Cuánto tiempo les lleva armar y emitir una factura, en promedio?'),
    ('facturacion', 'emision-de-facturas', '¿Quién factura hoy — una persona, varias, es parte de otra tarea?'),
    ('facturacion', 'control-y-sistemas', '¿Se les pierden o duplican comprobantes alguna vez? ¿Con qué frecuencia?'),
    ('facturacion', 'control-y-sistemas', '¿La facturación está conectada con stock/pedidos, o son sistemas separados?'),
    ('facturacion', 'control-y-sistemas', '¿Usan algún ERP o sistema contable? ¿Cuál?'),
    ('facturacion', 'control-y-sistemas', '¿Cuánto les cuesta hoy (en horas o en plata) todo el proceso de facturación por mes?'),
    ('stock-y-logistica', 'control-de-inventario', '¿Cómo controlan el stock hoy — planilla, sistema, a ojo?'),
    ('stock-y-logistica', 'control-de-inventario', '¿Con qué frecuencia hacen recuento físico y cuánto tarda?'),
    ('stock-y-logistica', 'control-de-inventario', '¿Les pasó quedarse sin stock de algo que vendían seguido? ¿Cada cuánto?'),
    ('stock-y-logistica', 'control-de-inventario', '¿El stock está conectado con las ventas/facturación en tiempo real?'),
    ('stock-y-logistica', 'reposicion-y-gestion', '¿Cómo deciden cuánto reponer y cuándo?'),
    ('stock-y-logistica', 'reposicion-y-gestion', '¿Cuántos depósitos o puntos de stock manejan?'),
    ('stock-y-logistica', 'reposicion-y-gestion', '¿Quién es responsable del stock hoy?'),
    ('atencion-al-cliente', 'canales-y-volumen', '¿Por dónde entran las consultas de clientes hoy — WhatsApp, teléfono, mail, redes?'),
    ('atencion-al-cliente', 'canales-y-volumen', '¿Cuántas consultas reciben por día/semana, aproximadamente?'),
    ('atencion-al-cliente', 'canales-y-volumen', '¿Cuánto tardan en responder en promedio?'),
    ('atencion-al-cliente', 'calidad-de-atencion', '¿Hay preguntas que se repiten mucho y siempre se responden igual?'),
    ('atencion-al-cliente', 'calidad-de-atencion', '¿Quién atiende hoy — una persona dedicada, se reparte entre varios?'),
    ('atencion-al-cliente', 'calidad-de-atencion', '¿Pierden consultas o se demoran en responder fuera de horario?'),
    ('atencion-al-cliente', 'calidad-de-atencion', '¿Miden en algo la satisfacción del cliente o los tiempos de respuesta?'),
    ('rrhh', 'administracion-de-personal', '¿Cómo gestionan hoy legajos, licencias y asistencia?'),
    ('rrhh', 'administracion-de-personal', '¿Cómo es el proceso de liquidación de sueldos — interno, tercerizado, con qué herramienta?'),
    ('rrhh', 'administracion-de-personal', '¿Cuánto tiempo insume el proceso de liquidación por mes?'),
    ('rrhh', 'reclutamiento-y-retencion', '¿Cómo reclutan y seleccionan gente nueva hoy?'),
    ('rrhh', 'reclutamiento-y-retencion', '¿Tienen rotación alta en algún puesto? ¿Por qué, si lo saben?'),
    ('rrhh', 'reclutamiento-y-retencion', '¿Hay algo del proceso de RRHH que hoy se hace todo en papel o en planillas sueltas?'),
    ('produccion-y-operaciones', 'planificacion-y-registro', '¿Cómo planifican la producción hoy — por pedido, por stock, mixto?'),
    ('produccion-y-operaciones', 'planificacion-y-registro', '¿Cómo registran lo que se produce — a mano, planilla, sistema?'),
    ('produccion-y-operaciones', 'eficiencia-y-calidad', '¿Cuál es el cuello de botella más claro del proceso hoy?'),
    ('produccion-y-operaciones', 'eficiencia-y-calidad', '¿Miden tiempos de producción o de entrega? ¿Cómo?'),
    ('produccion-y-operaciones', 'eficiencia-y-calidad', '¿Tienen mermas o reprocesos frecuentes? ¿Se registran de alguna forma?'),
    ('produccion-y-operaciones', 'eficiencia-y-calidad', '¿Cuántas personas están involucradas en el proceso productivo?'),
    ('finanzas-y-costos', 'control-financiero', '¿Cómo llevan hoy el control de ingresos y egresos — planilla, sistema, contador externo?'),
    ('finanzas-y-costos', 'control-financiero', '¿Con qué frecuencia saben cuánto ganan o pierden — al día, semanal, recién a fin de mes?'),
    ('finanzas-y-costos', 'control-financiero', '¿Quién maneja la parte financiera hoy — el dueño, un administrativo, un estudio contable?'),
    ('finanzas-y-costos', 'costeo-y-planificacion', '¿Cómo calculan el costo de cada producto o servicio?'),
    ('finanzas-y-costos', 'costeo-y-planificacion', '¿Tienen problemas de flujo de caja — se les complica pagar en algún momento del mes?'),
    ('finanzas-y-costos', 'costeo-y-planificacion', '¿Usan algún presupuesto anual o proyección, o van mes a mes?'),
    ('compras-y-proveedores', 'gestion-de-proveedores', '¿Cómo deciden a quién y cuándo comprar hoy?'),
    ('compras-y-proveedores', 'gestion-de-proveedores', '¿Cuántos proveedores clave manejan y qué tan dependientes son de alguno en particular?'),
    ('compras-y-proveedores', 'gestion-de-proveedores', '¿Comparan precios entre proveedores de forma sistemática o es más informal?'),
    ('compras-y-proveedores', 'seguimiento-de-pedidos', '¿Cómo hacen el seguimiento de pedidos a proveedores — llamados, mail, algún sistema?'),
    ('compras-y-proveedores', 'seguimiento-de-pedidos', '¿Les pasó tener problemas de calidad o de entrega con algún proveedor? ¿Con qué frecuencia?'),
    ('ventas-y-comercial', 'proceso-comercial', '¿Cómo es el proceso desde que un cliente muestra interés hasta que compra?'),
    ('ventas-y-comercial', 'proceso-comercial', '¿Usan algún CRM o planilla para seguir a los clientes potenciales?'),
    ('ventas-y-comercial', 'proceso-comercial', '¿Cuánto tardan en promedio en cerrar una venta?'),
    ('ventas-y-comercial', 'gestion-de-oportunidades', '¿Saben cuántos presupuestos o cotizaciones mandan por mes y cuántos se concretan?'),
    ('ventas-y-comercial', 'gestion-de-oportunidades', '¿Hacen seguimiento a clientes que cotizaron y no compraron?'),
    ('ventas-y-comercial', 'gestion-de-oportunidades', '¿Quién vende hoy — el dueño, un equipo comercial, se reparte?'),
    ('marketing-y-redes', 'canales-y-comunicacion', '¿Qué canales usan hoy para darse a conocer — redes, boca a boca, publicidad paga?'),
    ('marketing-y-redes', 'canales-y-comunicacion', '¿Quién maneja las redes o la comunicación — interno, freelance, agencia?'),
    ('marketing-y-redes', 'medicion-y-presupuesto', '¿Miden de alguna forma qué tan efectivo es lo que publican o invierten?'),
    ('marketing-y-redes', 'medicion-y-presupuesto', '¿Cómo saben de dónde vienen sus clientes nuevos?'),
    ('marketing-y-redes', 'medicion-y-presupuesto', '¿Tienen algún presupuesto asignado a marketing o es esporádico?'),
    ('tecnologia-e-infraestructura-it', 'sistemas', '¿Qué sistemas o software usan hoy para el día a día?'),
    ('tecnologia-e-infraestructura-it', 'sistemas', '¿Esos sistemas están conectados entre sí o cada uno funciona por separado?'),
    ('tecnologia-e-infraestructura-it', 'sistemas', '¿Qué edad tiene el equipamiento/infraestructura principal (servidores, PCs, red)?'),
    ('tecnologia-e-infraestructura-it', 'soporte-y-continuidad', '¿Tienen a alguien (interno o externo) que se ocupe de IT?'),
    ('tecnologia-e-infraestructura-it', 'soporte-y-continuidad', '¿Tuvieron problemas de pérdida de información o caídas de sistema?'),
    ('tecnologia-e-infraestructura-it', 'soporte-y-continuidad', '¿Cómo hacen backups de la información crítica, si es que hacen?'),
    ('calidad', 'estandares', '¿Tienen algún estándar o checklist de calidad definido, o es más a criterio de cada uno?'),
    ('calidad', 'estandares', '¿Tienen alguna certificación de calidad o están en proceso?'),
    ('calidad', 'deteccion-y-registro', '¿Cómo detectan hoy un producto o servicio con problemas — antes o después de llegar al cliente?'),
    ('calidad', 'deteccion-y-registro', '¿Registran de alguna forma las quejas o devoluciones de clientes?'),
    ('mantenimiento', 'tipo-de-mantenimiento', '¿El mantenimiento de equipos es preventivo o solo arreglan cuando se rompe algo?'),
    ('mantenimiento', 'tipo-de-mantenimiento', '¿Quién se ocupa del mantenimiento — interno, tercerizado?'),
    ('mantenimiento', 'registro-e-impacto', '¿Llevan algún registro de fallas o paradas de equipos?'),
    ('mantenimiento', 'registro-e-impacto', '¿Cuánto les cuesta en tiempo/plata una parada no planificada, aproximadamente?'),
    ('legal-y-compliance', 'documentacion', '¿Están al día con la documentación laboral, impositiva y de habilitaciones?'),
    ('legal-y-compliance', 'documentacion', '¿Tienen contratos formales con clientes/proveedores clave, o funcionan más de palabra?'),
    ('legal-y-compliance', 'riesgo-y-asesoria', '¿Alguna vez tuvieron un problema legal o una multa que se podría haber evitado?'),
    ('legal-y-compliance', 'riesgo-y-asesoria', '¿Quién los asesora en temas legales/impositivos hoy?'),
    ('administracion-general', 'organizacion', '¿Cómo está organizado el equipo hoy — organigrama claro o roles superpuestos?'),
    ('administracion-general', 'organizacion', '¿Qué pasa si el dueño/gerente se va una semana — la operación sigue sin problema?'),
    ('administracion-general', 'procesos-y-documentacion', '¿Hay procesos documentados por escrito o el conocimiento está solo en la cabeza de la gente?'),
    ('administracion-general', 'procesos-y-documentacion', '¿Cuál dirían ustedes mismos que es el cuello de botella más grande hoy?')
)
update preguntas p
set subproceso_id = s.id
from mapeo m
join temas t on t.slug = m.tema_slug
join subprocesos s on s.tema_id = t.id and s.slug = m.subproceso_slug
where p.tema_id = t.id and p.texto = m.texto;

-- cualquier pregunta nueva que hayas cargado vos manualmente y que haya
-- quedado sin subproceso (por no matchear ningún texto de arriba) queda
-- agrupada en un subproceso "General" por tema, para no perderla de vista.
insert into subprocesos (tema_id, nombre, slug, orden)
select distinct t.id, 'General', 'general', 99
from preguntas p
join temas t on t.id = p.tema_id
where p.subproceso_id is null
on conflict (tema_id, slug) do nothing;

update preguntas p
set subproceso_id = s.id
from subprocesos s
where p.subproceso_id is null and s.tema_id = p.tema_id and s.slug = 'general';
