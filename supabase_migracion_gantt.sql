-- Agrega el campo donde vive el Gantt estructurado (tareas con semana de
-- inicio/fin y responsable) para poder dibujarlo como barras de colores
-- y editarlo, en vez de tenerlo como texto plano dentro de la propuesta.

alter table propuestas add column if not exists gantt jsonb;
