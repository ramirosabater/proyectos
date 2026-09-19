-- Base de conocimiento: casos, benchmarks, aprendizajes o investigación
-- que Ramiro (o Claude, pegado por Ramiro) va guardando por tema. Se usa
-- como contexto extra al generar una propuesta de ese tema.

create table if not exists conocimiento (
  id uuid primary key default gen_random_uuid(),
  tema_id uuid references temas(id) on delete set null,
  titulo text not null,
  contenido text not null,
  fuente text, -- opcional: "reunión con Metalúrgica Andina", "investigación web", un link, etc.
  creado_at timestamptz not null default now()
);

alter table conocimiento enable row level security;

create policy "autenticados_leen_conocimiento" on conocimiento
  for select using (auth.role() = 'authenticated');
create policy "autenticados_escriben_conocimiento" on conocimiento
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
