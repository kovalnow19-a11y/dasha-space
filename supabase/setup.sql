-- =====================================================================
-- Кабинет dasha-space · настройка Supabase
-- Можно запускать повторно: ничего не дублирует и не удаляет данные.
-- =====================================================================

-- 1. Таблица записей кабинета: одна строка = одна запись
create table if not exists public.cabinet_items (
  user_id    uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  kind       text        not null check (kind ~ '^[a-z_]{1,32}$'),
  item_id    text        not null check (char_length(item_id) between 1 and 80),
  data       jsonb       not null default '{}'::jsonb check (octet_length(data::text) <= 1000000),
  deleted    boolean     not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, item_id)
);

create index if not exists cabinet_items_user_updated_idx
  on public.cabinet_items (user_id, updated_at);

-- время изменения ставит сервер, а не телефон или компьютер
create or replace function public.cabinet_items_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists cabinet_items_touch on public.cabinet_items;
create trigger cabinet_items_touch
  before insert or update on public.cabinet_items
  for each row execute function public.cabinet_items_touch();

-- 2. Доступ: гостям ничего, вошедшему пользователю — только свои строки
revoke all on public.cabinet_items from anon;
grant select, insert, update, delete on public.cabinet_items to authenticated;

alter table public.cabinet_items enable row level security;

drop policy if exists "items: read own"   on public.cabinet_items;
drop policy if exists "items: insert own" on public.cabinet_items;
drop policy if exists "items: update own" on public.cabinet_items;
drop policy if exists "items: delete own" on public.cabinet_items;

create policy "items: read own" on public.cabinet_items
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "items: insert own" on public.cabinet_items
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "items: update own" on public.cabinet_items
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "items: delete own" on public.cabinet_items
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 3. Приватная папка для картинок (до 5 МБ на файл, только изображения)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', false, 5242880, array['image/webp', 'image/jpeg', 'image/png'])
on conflict (id) do update
  set public             = false,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- файлы лежат по пути  <id пользователя>/<id картинки>
drop policy if exists "media: read own"   on storage.objects;
drop policy if exists "media: upload own" on storage.objects;
drop policy if exists "media: update own" on storage.objects;
drop policy if exists "media: delete own" on storage.objects;

create policy "media: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "media: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "media: update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "media: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- 4. Проверка: должно получиться true / true / 4 / 4
select 'Защита таблицы (RLS) включена' as "Проверка", relrowsecurity::text as "Результат"
  from pg_class where oid = 'public.cabinet_items'::regclass
union all
select 'Папка media закрыта', (not public)::text
  from storage.buckets where id = 'media'
union all
select 'Правил для таблицы', count(*)::text
  from pg_policies where schemaname = 'public' and tablename = 'cabinet_items'
union all
select 'Правил для картинок', count(*)::text
  from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'media:%';
