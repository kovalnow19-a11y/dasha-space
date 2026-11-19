-- =====================================================================
-- Кабинет dasha-space · учебные материалы раздела «Саморазвитие»
-- Приватная папка learning-files: PDF, изображения, DOCX/DOC/ODT/RTF/TXT/MD
-- до 20 МБ на файл. Путь файла: <id пользователя>/<id файла>.<расширение>,
-- доступ — только владельцу (по user_id из входа).
-- Описания файлов (название, размер, тип) хранятся в уже существующей
-- таблице cabinet_items — для неё ничего делать не нужно.
-- Видео с YouTube не загружаются: хранятся только ссылки.
-- Можно запускать повторно: ничего не дублирует и не удаляет файлы.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('learning-files', 'learning-files', false, 20971520,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/webp',
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
              'application/msword', 'application/vnd.oasis.opendocument.text',
              'application/rtf', 'text/plain', 'text/markdown'])
on conflict (id) do update
  set public             = false,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "learning-files: read own"   on storage.objects;
drop policy if exists "learning-files: upload own" on storage.objects;
drop policy if exists "learning-files: update own" on storage.objects;
drop policy if exists "learning-files: delete own" on storage.objects;

create policy "learning-files: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'learning-files' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "learning-files: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'learning-files' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "learning-files: update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'learning-files' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'learning-files' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "learning-files: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'learning-files' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Проверка: должно получиться true / 20 МБ / 4
select 'Папка learning-files закрыта' as "Проверка", (not public)::text as "Результат"
  from storage.buckets where id = 'learning-files'
union all
select 'Лимит на один файл', (file_size_limit / 1048576)::text || ' МБ'
  from storage.buckets where id = 'learning-files'
union all
select 'Правил для учебных файлов', count(*)::text
  from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'learning-files:%';
