-- Links de solo-lectura para compartir una propuesta puntual con el
-- cliente, sin que necesite loguearse. El acceso público pasa por una
-- función de Netlify que usa la service_role key (nunca la anon key) para
-- leer sin pasar por el login — por eso esta tabla NO necesita política de
-- lectura pública: nadie de afuera le pega directo a Supabase, todos pasan
-- por la función.

create table if not exists shares (
  id uuid primary key default gen_random_uuid(),
  propuesta_id uuid not null references propuestas(id) on delete cascade,
  creado_at timestamptz not null default now()
);

alter table shares enable row level security;

create policy "autenticados_crean_shares" on shares
  for insert with check (auth.role() = 'authenticated');
create policy "autenticados_ven_sus_shares" on shares
  for select using (auth.role() = 'authenticated');
create policy "autenticados_borran_shares" on shares
  for delete using (auth.role() = 'authenticated');
