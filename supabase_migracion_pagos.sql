-- Cobros de cada propuesta (lo usan la sección "Cobros" y la pestaña Tablero).
-- Es seguro correrlo aunque ya hayas creado la tabla a mano: no pisa nada,
-- solo agrega lo que falte.

create table if not exists pagos (
  id uuid primary key default gen_random_uuid(),
  propuesta_id uuid not null references propuestas(id) on delete cascade,
  descripcion text not null,
  monto numeric not null,
  estado text not null default 'pendiente', -- 'pendiente' | 'cobrado'
  fecha_cobro date,
  creado_at timestamptz not null default now()
);

alter table pagos add column if not exists estado text not null default 'pendiente';
alter table pagos add column if not exists fecha_cobro date;

alter table pagos enable row level security;

drop policy if exists "autenticados_leen_pagos" on pagos;
drop policy if exists "autenticados_escriben_pagos" on pagos;

create policy "autenticados_leen_pagos" on pagos
  for select using (auth.role() = 'authenticated');
create policy "autenticados_escriben_pagos" on pagos
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
