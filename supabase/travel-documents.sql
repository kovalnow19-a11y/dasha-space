-- =====================================================================
-- Кабинет dasha-space · документы поездок
-- Приватная папка travel-documents: PDF, JPG, PNG, WEBP до 20 МБ на файл.
-- Файлы лежат по пути  <id пользователя>/<id документа>.<расширение>,
-- доступ — только владельцу (по user_id из входа).
-- Записи о документах (название, категория, дата, заметка) хранятся
-- в уже созданной таблице travel_items — для неё ничего делать не нужно.
-- Можно запускать повторно: ничего не дублирует и не удаляет файлы.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('travel-documents', 'travel-documents', false, 20971520,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public             = false,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "travel-docs: read own"   on storage.objects;
drop policy if exists "travel-docs: upload own" on storage.objects;
drop policy if exists "travel-docs: update own" on storage.objects;
drop policy if exists "travel-docs: delete own" on storage.objects;

create policy "travel-docs: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'travel-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "travel-docs: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'travel-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "travel-docs: update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'travel-documents' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'travel-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "travel-docs: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'travel-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Проверка: должно получиться true / 20 МБ / 4
select 'Папка travel-documents закрыта' as "Проверка", (not public)::text as "Результат"
  from storage.buckets where id = 'travel-documents'
union all
select 'Лимит на один файл', (file_size_limit / 1048576)::text || ' МБ'
  from storage.buckets where id = 'travel-documents'
union all
select 'Правил для документов', count(*)::text
  from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'travel-docs:%';
