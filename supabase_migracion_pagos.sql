-- Registro de cobros por propuesta: cada fila es un pago esperado o
-- realizado (pago único, una cuota, etc.). El tablero de control agrega
-- esto para mostrar facturación estimada, cobrado y pendiente.

create table if not exists pagos (
  id uuid primary key default gen_random_uuid(),
  propuesta_id uuid not null references propuestas(id) on delete cascade,
  descripcion text not null, -- ej. "Pago único", "Cuota 1/3"
  monto numeric not null,
  estado text not null default 'pendiente', -- 'pendiente' | 'cobrado'
  fecha_estimada date,
  fecha_cobro date,
  creado_at timestamptz not null default now()
);

alter table pagos enable row level security;
create policy "autenticados_leen_pagos" on pagos
  for select using (auth.role() = 'authenticated');
create policy "autenticados_escriben_pagos" on pagos
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
