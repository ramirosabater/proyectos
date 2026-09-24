-- Cartera Viva adentro del Cuaderno: tablero de proyectos por etapa,
-- reuniones por proyecto y avance automático de etapas.
-- Correr DESPUÉS de supabase_migracion_clientes.sql.
-- Se puede correr más de una vez sin problema.

create extension if not exists "pgcrypto";

create table if not exists proyectos (
  id uuid primary key default gen_random_uuid(),
  nombre text,
  creado_at timestamptz not null default now()
);

-- ---------- campos del proyecto ----------
alter table proyectos add column if not exists estado text;
alter table proyectos add column if not exists responsable text;
alter table proyectos add column if not exists proxima_accion text;
alter table proyectos add column if not exists proxima_fecha date;
alter table proyectos add column if not exists valor_estimado numeric;
alter table proyectos add column if not exists moneda text not null default 'ARS';
alter table proyectos add column if not exists perdido boolean not null default false;
alter table proyectos add column if not exists motivo_perdido text;
alter table proyectos add column if not exists actualizado_at timestamptz not null default now();

-- Tamaño de la empresa (lo tenía Cartera Viva).
alter table clientes add column if not exists tamanio text;

-- Vínculo proyecto → cliente, con el mismo tipo que clientes.id.
do $$
declare tipo_cliente text;
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'proyectos' and column_name = 'cliente_id') then
    select format_type(a.atttypid, a.atttypmod) into tipo_cliente
      from pg_attribute a
     where a.attrelid = 'public.clientes'::regclass and a.attname = 'id' and not a.attisdropped;
    execute format('alter table proyectos add column cliente_id %s references clientes(id) on delete set null', tipo_cliente);
  end if;
end $$;

-- Permiso para el usuario logueado (las políticas se suman, no quitan nada).
alter table proyectos enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'proyectos' and policyname = 'autenticados_gestionan_proyectos') then
    create policy "autenticados_gestionan_proyectos" on proyectos
      for all to authenticated using (true) with check (true);
  end if;
end $$;

-- ---------- reuniones de cada proyecto ----------
-- La tabla se llama proyecto_reuniones para no chocar con una tabla
-- "reuniones" que ya existe en tu Supabase (de otra app o versión
-- anterior). Esa tabla no se toca.
do $$
declare tipo_proyecto text;
begin
  select format_type(a.atttypid, a.atttypmod) into tipo_proyecto
    from pg_attribute a
   where a.attrelid = 'public.proyectos'::regclass and a.attname = 'id' and not a.attisdropped;

  execute format('alter table propuestas add column if not exists proyecto_id %s references proyectos(id) on delete set null', tipo_proyecto);

  execute format($f$
    create table if not exists proyecto_reuniones (
      id uuid primary key default gen_random_uuid(),
      proyecto_id %s not null references proyectos(id) on delete cascade,
      fecha date not null default current_date,
      tipo text not null default 'Relevamiento', -- Relevamiento | Seguimiento | Presentación de propuesta | Kickoff | Otra
      resumen text not null,
      creado_at timestamptz not null default now()
    )$f$, tipo_proyecto);
end $$;

create index if not exists idx_proyecto_reuniones on proyecto_reuniones (proyecto_id, fecha desc);

alter table proyecto_reuniones enable row level security;
drop policy if exists "autenticados_gestionan_reuniones" on proyecto_reuniones;
create policy "autenticados_gestionan_reuniones" on proyecto_reuniones
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- La propuesta recuerda de qué reunión salió.
alter table propuestas add column if not exists reunion_id uuid references proyecto_reuniones(id) on delete set null;

-- ---------- la etapa del proyecto avanza sola ----------
-- Orden: contacto_inicial → relevamiento_agendado → relevamiento_hecho →
--        propuesta_enviada → en_desarrollo → ganado.
-- Solo avanza, nunca retrocede, y nunca frena el guardado original.
create or replace function orden_etapa_proyecto(e text) returns int
language sql immutable as $$
  select coalesce(array_position(array[
    'contacto_inicial','relevamiento_agendado','relevamiento_hecho',
    'propuesta_enviada','en_desarrollo','ganado'], e), 0)
$$;

create or replace function avanzar_proyecto(pid anyelement, nueva text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update proyectos
     set estado = nueva, actualizado_at = now()
   where id = pid
     and not perdido
     and orden_etapa_proyecto(estado) < orden_etapa_proyecto(nueva);
exception when others then
  null;
end;
$$;

-- Reunión de relevamiento cargada → "Relevamiento hecho".
create or replace function trg_reunion_avanza() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.tipo = 'Relevamiento' then perform avanzar_proyecto(new.proyecto_id, 'relevamiento_hecho'); end if;
  return new;
end;
$$;
drop trigger if exists trg_reunion_avanza on proyecto_reuniones;
create trigger trg_reunion_avanza after insert on proyecto_reuniones
  for each row execute function trg_reunion_avanza();

-- Link de la propuesta compartido con el cliente → "Propuesta enviada".
create or replace function trg_share_avanza() returns trigger
language plpgsql security definer set search_path = public as $$
declare pid proyectos.id%type;
begin
  select proyecto_id into pid from propuestas where id = new.propuesta_id;
  if pid is not null then perform avanzar_proyecto(pid, 'propuesta_enviada'); end if;
  return new;
end;
$$;
drop trigger if exists trg_share_avanza on shares;
create trigger trg_share_avanza after insert on shares
  for each row execute function trg_share_avanza();

-- Propuesta aceptada → "En desarrollo".
create or replace function trg_aceptada_avanza() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.estado = 'aceptada' and old.estado is distinct from 'aceptada' and new.proyecto_id is not null then
    perform avanzar_proyecto(new.proyecto_id, 'en_desarrollo');
  end if;
  return new;
end;
$$;
drop trigger if exists trg_aceptada_avanza on propuestas;
create trigger trg_aceptada_avanza after update of estado on propuestas
  for each row execute function trg_aceptada_avanza();
