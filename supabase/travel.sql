-- =====================================================================
-- Кабинет dasha-space · раздел «Путешествия»
-- Отдельная таблица для поездок и маршрутов. Устроена так же, как cabinet_items.
-- Можно запускать повторно: ничего не дублирует и не удаляет данные.
-- =====================================================================

create table if not exists public.travel_items (
  user_id    uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  kind       text        not null check (kind ~ '^[a-z_]{1,32}$'),
  item_id    text        not null check (char_length(item_id) between 1 and 80),
  data       jsonb       not null default '{}'::jsonb check (octet_length(data::text) <= 1000000),
  deleted    boolean     not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, item_id)
);

create index if not exists travel_items_user_updated_idx
  on public.travel_items (user_id, updated_at);

-- время изменения ставит сервер (функция уже создана скриптом setup.sql)
drop trigger if exists travel_items_touch on public.travel_items;
create trigger travel_items_touch
  before insert or update on public.travel_items
  for each row execute function public.cabinet_items_touch();

-- доступ: гостям ничего, вошедшему пользователю — только свои строки
revoke all on public.travel_items from anon;
grant select, insert, update, delete on public.travel_items to authenticated;

alter table public.travel_items enable row level security;

drop policy if exists "travel: read own"   on public.travel_items;
drop policy if exists "travel: insert own" on public.travel_items;
drop policy if exists "travel: update own" on public.travel_items;
drop policy if exists "travel: delete own" on public.travel_items;

create policy "travel: read own" on public.travel_items
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "travel: insert own" on public.travel_items
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "travel: update own" on public.travel_items
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "travel: delete own" on public.travel_items
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Проверка: должно получиться true / 4
select 'Защита таблицы поездок (RLS) включена' as "Проверка", relrowsecurity::text as "Результат"
  from pg_class where oid = 'public.travel_items'::regclass
union all
select 'Правил для таблицы поездок', count(*)::text
  from pg_policies where schemaname = 'public' and tablename = 'travel_items';
