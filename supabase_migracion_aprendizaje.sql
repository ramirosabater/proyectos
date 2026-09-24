-- Paquete "la herramienta aprende sola":
--   1. Guarda el análisis de cada reunión (preguntas que quedaron sin
--      responder + preguntas nuevas sugeridas para el banco).
--   2. Cuando una propuesta pasa a "aceptada" (la acepte el cliente desde
--      el link o como sea), se guarda sola un resumen del caso en
--      Conocimiento, así las próximas propuestas de ese tema se calibran
--      con casos reales tuyos.
-- Se puede correr más de una vez sin problema.

-- ---------- 1. análisis de la reunión ----------
-- Queda solo del lado interno: ver-propuesta.js pide columnas puntuales,
-- así que esto nunca llega al link que ve el cliente.
alter table propuestas add column if not exists analisis jsonb;

-- ---------- 2. conocimiento automático ----------
alter table conocimiento add column if not exists propuesta_id uuid references propuestas(id) on delete set null;

create or replace function guardar_caso_aceptado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  c jsonb;
  semanas int;
  etapas text;
  texto text;
begin
  if new.estado <> 'aceptada' or old.estado is not distinct from 'aceptada' then
    return new;
  end if;

  -- Si este caso ya se guardó antes (por ejemplo, la desmarcaste y la
  -- volviste a aceptar), no se duplica.
  if exists (select 1 from conocimiento where propuesta_id = new.id) then
    return new;
  end if;

  -- Todo lo que sigue va protegido: si algo del contenido viene raro, el
  -- caso no se guarda, pero la aceptación de la propuesta nunca falla.
  begin
  c := new.contenido::jsonb;

  select max(round((el->>'semana_fin')::numeric)::int), string_agg(el->>'tarea', ', ')
    into semanas, etapas
    from jsonb_array_elements(
      case when jsonb_typeof(coalesce(new.gantt, c->'gantt')) = 'array'
           then coalesce(new.gantt, c->'gantt') else '[]'::jsonb end
    ) as g(el);

  texto := concat_ws(E'\n',
    'Dolor: ' || nullif(c->>'dolor', ''),
    'Solución: ' || nullif(c->>'solucion', ''),
    'Inversión acordada: ' || nullif(c->>'inversion', ''),
    case when semanas is not null then 'Duración estimada: ' || semanas || ' semanas (' || etapas || ')' end,
    'Criterios de éxito: ' || replace(nullif(c->>'criterios_exito', ''), E'\n', '; ')
  );

  insert into conocimiento (tema_id, titulo, contenido, fuente, propuesta_id)
  values (
    new.tema_id,
    'Caso aceptado: ' || coalesce(nullif(new.cliente_texto, ''), 'sin cliente'),
    texto,
    'propuesta aceptada el ' || to_char(coalesce(new.aceptado_at, now()), 'DD/MM/YYYY'),
    new.id
  );
  exception when others then
    return new;
  end;

  return new;
end;
$$;

drop trigger if exists trg_guardar_caso_aceptado on propuestas;
create trigger trg_guardar_caso_aceptado
  after update of estado on propuestas
  for each row execute function guardar_caso_aceptado();
