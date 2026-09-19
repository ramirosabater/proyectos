-- Bucket privado (no accesible por URL directa sin firmar) para fotos,
-- planos, capturas, etc. que quieras dejar guardadas junto a un proyecto.

insert into storage.buckets (id, name, public)
values ('adjuntos-proyecto', 'adjuntos-proyecto', false)
on conflict (id) do nothing;

create policy "autenticados_suben_adjuntos" on storage.objects
  for insert with check (bucket_id = 'adjuntos-proyecto' and auth.role() = 'authenticated');
create policy "autenticados_ven_adjuntos" on storage.objects
  for select using (bucket_id = 'adjuntos-proyecto' and auth.role() = 'authenticated');
create policy "autenticados_borran_adjuntos" on storage.objects
  for delete using (bucket_id = 'adjuntos-proyecto' and auth.role() = 'authenticated');
