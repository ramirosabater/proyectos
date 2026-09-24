-- Gestión de clientes: ficha, contactos, bitácora de interacciones y
-- próximo contacto.
--
-- Usa la tabla `clientes` que ya exista en Supabase y solo le AGREGA
-- columnas nuevas y opcionales. Si la tabla no existiera, la crea.
-- Se puede correr más de una vez sin problema.

create extension if not exists "pgcrypto";

create table if not exists clientes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  creado_at timestamptz not null default now()
);

-- ---------- ficha del cliente ----------
alter table clientes add column if not exists razon_social text;
alter table clientes add column if not exists cuit text;
alter table clientes add column if not exists rubro text;
alter table clientes add column if not exists localidad text;
alter table clientes add column if not exists direccion text;
alter table clientes add column if not exists web text;
alter table clientes add column if not exists origen text;          -- cómo llegó: referido, LinkedIn, evento...
alter table clientes add column if not exists notas_internas text;
alter table clientes add column if not exists contactos jsonb not null default '[]'::jsonb;
  -- [{ "nombre", "cargo", "email", "telefono", "principal": true|false }]
alter table clientes add column if not exists proximo_contacto date;
alter table clientes add column if not exists proxima_accion text;

-- Etapa comercial: prospecto → propuesta → cliente → inactivo.
-- Los clientes que ya tenías cargados arrancan como "cliente"; los
-- nuevos, como "prospecto".
do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'clientes' and column_name = 'etapa_comercial') then
    alter table clientes add column etapa_comercial text;
    update clientes set etapa_comercial = 'cliente';
    alter table clientes alter column etapa_comercial set default 'prospecto';
  end if;
end $$;

-- Control: si la tabla ya tenía una columna "contactos" de otro tipo,
-- frenamos acá con un mensaje claro en vez de romper algo después.
do $$
begin
  if (select data_type from information_schema.columns
      where table_schema = 'public' and table_name = 'clientes' and column_name = 'contactos') <> 'jsonb' then
    raise exception 'La tabla clientes ya tenía una columna "contactos" que no es jsonb. Avisale a Claude antes de seguir.';
  end if;
end $$;

-- Permiso para el usuario logueado de esta app. Las políticas se suman
-- (OR), así que no le quita permisos a nadie.
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'clientes' and policyname = 'autenticados_gestionan_clientes') then
    create policy "autenticados_gestionan_clientes" on clientes
      for all to authenticated using (true) with check (true);
  end if;
end $$;

-- ---------- vínculo propuesta → cliente y bitácora ----------
-- El tipo de clientes.id se detecta solo (uuid, bigint, lo que tenga),
-- así las referencias siempre coinciden.
do $$
declare
  tipo_id text;
begin
  select format_type(a.atttypid, a.atttypmod) into tipo_id
    from pg_attribute a
   where a.attrelid = 'public.clientes'::regclass and a.attname = 'id' and not a.attisdropped;

  execute format('alter table propuestas add column if not exists cliente_id %s references clientes(id) on delete set null', tipo_id);

  execute format($f$
    create table if not exists cliente_interacciones (
      id uuid primary key default gen_random_uuid(),
      cliente_id %s not null references clientes(id) on delete cascade,
      fecha date not null default current_date,
      tipo text not null default 'nota',   -- llamada | reunion | mail | whatsapp | nota
      detalle text not null,
      creado_at timestamptz not null default now()
    )$f$, tipo_id);
end $$;

create index if not exists idx_interacciones_cliente on cliente_interacciones (cliente_id, fecha desc);
create index if not exists idx_propuestas_cliente on propuestas (cliente_id);

alter table cliente_interacciones enable row level security;
drop policy if exists "autenticados_gestionan_interacciones" on cliente_interacciones;
create policy "autenticados_gestionan_interacciones" on cliente_interacciones
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ---------- vincular las propuestas que ya tenías ----------
-- Por el nombre escrito en la propuesta (sin distinguir mayúsculas).
update propuestas p
   set cliente_id = c.id
  from clientes c
 where p.cliente_id is null
   and p.cliente_texto is not null
   and lower(trim(p.cliente_texto)) = lower(trim(c.nombre));

-- Y por el proyecto, si proyectos tiene columna cliente_id.
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'proyectos' and column_name = 'cliente_id') then
    execute 'update propuestas p set cliente_id = pr.cliente_id
               from proyectos pr
              where p.cliente_id is null and p.proyecto_id = pr.id and pr.cliente_id is not null';
  end if;
end $$;

-- ---------- la etapa avanza sola ----------
-- Nueva propuesta para un prospecto → pasa a "propuesta".
-- Propuesta aceptada → pasa a "cliente".
-- Nunca frena el guardado de la propuesta aunque algo falle.
create or replace function actualizar_etapa_cliente()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.cliente_id is null then return new; end if;
  begin
    if tg_op = 'INSERT' then
      update clientes set etapa_comercial = 'propuesta'
       where id = new.cliente_id and coalesce(etapa_comercial, 'prospecto') = 'prospecto';
    elsif new.estado = 'aceptada' and old.estado is distinct from 'aceptada' then
      update clientes set etapa_comercial = 'cliente'
       where id = new.cliente_id and coalesce(etapa_comercial, 'prospecto') in ('prospecto', 'propuesta', 'inactivo');
    end if;
  exception when others then
    return new;
  end;
  return new;
end;
$$;

drop trigger if exists trg_etapa_cliente_insert on propuestas;
create trigger trg_etapa_cliente_insert
  after insert on propuestas
  for each row execute function actualizar_etapa_cliente();

drop trigger if exists trg_etapa_cliente_update on propuestas;
create trigger trg_etapa_cliente_update
  after update of estado on propuestas
  for each row execute function actualizar_etapa_cliente();
