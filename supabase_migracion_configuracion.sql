create table if not exists configuracion (
  id text primary key default '1',
  nombre_negocio text,
  logo_base64 text,
  tarifa_hora numeric,
  actualizado_at timestamptz not null default now()
);
insert into configuracion (id) values ('1') on conflict (id) do nothing;

alter table configuracion enable row level security;
create policy "autenticados_leen_configuracion" on configuracion
  for select using (auth.role() = 'authenticated');
create policy "autenticados_escriben_configuracion" on configuracion
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
