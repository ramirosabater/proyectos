-- Ampliación del banco de preguntas: más temas típicos de un relevamiento
-- de pyme (finanzas/costos, compras, ventas, marketing, IT, calidad,
-- mantenimiento, legal/compliance, administración general) — categorías
-- tomadas de cómo se estructura habitualmente un prediagnóstico de
-- consultoría pyme. Correr en el SQL Editor de Supabase, igual que la
-- migración anterior.

insert into temas (nombre, slug) values
  ('Finanzas y costos', 'finanzas-y-costos'),
  ('Compras y proveedores', 'compras-y-proveedores'),
  ('Ventas y comercial', 'ventas-y-comercial'),
  ('Marketing y redes', 'marketing-y-redes'),
  ('Tecnología e infraestructura IT', 'tecnologia-e-infraestructura-it'),
  ('Calidad', 'calidad'),
  ('Mantenimiento', 'mantenimiento'),
  ('Legal y compliance', 'legal-y-compliance'),
  ('Administración general', 'administracion-general')
on conflict (slug) do nothing;

insert into preguntas (tema_id, texto, orden)
select t.id, q.texto, q.orden
from temas t
join (values
  ('finanzas-y-costos', '¿Cómo llevan hoy el control de ingresos y egresos — planilla, sistema, contador externo?', 1),
  ('finanzas-y-costos', '¿Con qué frecuencia saben cuánto ganan o pierden — al día, semanal, recién a fin de mes?', 2),
  ('finanzas-y-costos', '¿Cómo calculan el costo de cada producto o servicio?', 3),
  ('finanzas-y-costos', '¿Tienen problemas de flujo de caja — se les complica pagar en algún momento del mes?', 4),
  ('finanzas-y-costos', '¿Quién maneja la parte financiera hoy — el dueño, un administrativo, un estudio contable?', 5),
  ('finanzas-y-costos', '¿Usan algún presupuesto anual o proyección, o van mes a mes?', 6),
  ('compras-y-proveedores', '¿Cómo deciden a quién y cuándo comprar hoy?', 1),
  ('compras-y-proveedores', '¿Cuántos proveedores clave manejan y qué tan dependientes son de alguno en particular?', 2),
  ('compras-y-proveedores', '¿Cómo hacen el seguimiento de pedidos a proveedores — llamados, mail, algún sistema?', 3),
  ('compras-y-proveedores', '¿Les pasó tener problemas de calidad o de entrega con algún proveedor? ¿Con qué frecuencia?', 4),
  ('compras-y-proveedores', '¿Comparan precios entre proveedores de forma sistemática o es más informal?', 5),
  ('ventas-y-comercial', '¿Cómo es el proceso desde que un cliente muestra interés hasta que compra?', 1),
  ('ventas-y-comercial', '¿Usan algún CRM o planilla para seguir a los clientes potenciales?', 2),
  ('ventas-y-comercial', '¿Cuánto tardan en promedio en cerrar una venta?', 3),
  ('ventas-y-comercial', '¿Saben cuántos presupuestos o cotizaciones mandan por mes y cuántos se concretan?', 4),
  ('ventas-y-comercial', '¿Hacen seguimiento a clientes que cotizaron y no compraron?', 5),
  ('ventas-y-comercial', '¿Quién vende hoy — el dueño, un equipo comercial, se reparte?', 6),
  ('marketing-y-redes', '¿Qué canales usan hoy para darse a conocer — redes, boca a boca, publicidad paga?', 1),
  ('marketing-y-redes', '¿Quién maneja las redes o la comunicación — interno, freelance, agencia?', 2),
  ('marketing-y-redes', '¿Miden de alguna forma qué tan efectivo es lo que publican o invierten?', 3),
  ('marketing-y-redes', '¿Cómo saben de dónde vienen sus clientes nuevos?', 4),
  ('marketing-y-redes', '¿Tienen algún presupuesto asignado a marketing o es esporádico?', 5),
  ('tecnologia-e-infraestructura-it', '¿Qué sistemas o software usan hoy para el día a día?', 1),
  ('tecnologia-e-infraestructura-it', '¿Esos sistemas están conectados entre sí o cada uno funciona por separado?', 2),
  ('tecnologia-e-infraestructura-it', '¿Tienen a alguien (interno o externo) que se ocupe de IT?', 3),
  ('tecnologia-e-infraestructura-it', '¿Tuvieron problemas de pérdida de información o caídas de sistema?', 4),
  ('tecnologia-e-infraestructura-it', '¿Cómo hacen backups de la información crítica, si es que hacen?', 5),
  ('tecnologia-e-infraestructura-it', '¿Qué edad tiene el equipamiento/infraestructura principal (servidores, PCs, red)?', 6),
  ('calidad', '¿Tienen algún estándar o checklist de calidad definido, o es más a criterio de cada uno?', 1),
  ('calidad', '¿Cómo detectan hoy un producto o servicio con problemas — antes o después de llegar al cliente?', 2),
  ('calidad', '¿Registran de alguna forma las quejas o devoluciones de clientes?', 3),
  ('calidad', '¿Tienen alguna certificación de calidad o están en proceso?', 4),
  ('mantenimiento', '¿El mantenimiento de equipos es preventivo o solo arreglan cuando se rompe algo?', 1),
  ('mantenimiento', '¿Llevan algún registro de fallas o paradas de equipos?', 2),
  ('mantenimiento', '¿Cuánto les cuesta en tiempo/plata una parada no planificada, aproximadamente?', 3),
  ('mantenimiento', '¿Quién se ocupa del mantenimiento — interno, tercerizado?', 4),
  ('legal-y-compliance', '¿Están al día con la documentación laboral, impositiva y de habilitaciones?', 1),
  ('legal-y-compliance', '¿Tienen contratos formales con clientes/proveedores clave, o funcionan más de palabra?', 2),
  ('legal-y-compliance', '¿Alguna vez tuvieron un problema legal o una multa que se podría haber evitado?', 3),
  ('legal-y-compliance', '¿Quién los asesora en temas legales/impositivos hoy?', 4),
  ('administracion-general', '¿Cómo está organizado el equipo hoy — organigrama claro o roles superpuestos?', 1),
  ('administracion-general', '¿Hay procesos documentados por escrito o el conocimiento está solo en la cabeza de la gente?', 2),
  ('administracion-general', '¿Qué pasa si el dueño/gerente se va una semana — la operación sigue sin problema?', 3),
  ('administracion-general', '¿Cuál dirían ustedes mismos que es el cuello de botella más grande hoy?', 4)
) as q(slug, texto, orden) on q.slug = t.slug
where not exists (
  select 1 from preguntas p where p.tema_id = t.id and p.texto = q.texto
);
