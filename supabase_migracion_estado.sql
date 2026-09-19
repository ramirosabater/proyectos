alter table propuestas add column if not exists estado text not null default 'pendiente';
alter table propuestas add column if not exists aceptado_at timestamptz;
-- estado: 'pendiente' | 'aceptada'
