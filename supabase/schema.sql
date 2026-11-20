create table if not exists public.household_members (
  user_id uuid primary key references auth.users (id) on delete cascade
);

alter table public.household_members enable row level security;
grant select on public.household_members to authenticated;

drop policy if exists "Members can view their own membership" on public.household_members;
create policy "Members can view their own membership"
  on public.household_members
  for select
  to authenticated
  using (user_id = auth.uid());

create table if not exists public.household_data (
  id text primary key check (id = 'home'),
  items jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.household_data enable row level security;
grant select, insert, update on public.household_data to authenticated;

drop policy if exists "Household members can read data" on public.household_data;
create policy "Household members can read data"
  on public.household_data
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

drop policy if exists "Household members can create data" on public.household_data;
create policy "Household members can create data"
  on public.household_data
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

drop policy if exists "Household members can update data" on public.household_data;
create policy "Household members can update data"
  on public.household_data
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

create table if not exists public.clothing_items (
  id text primary key,
  name text not null check (length(trim(name)) > 0),
  detail text not null default '',
  owner text check (owner in ('Ernest', 'Queralt', 'Dani', 'Estel')),
  created_at timestamptz not null default now()
);

alter table public.clothing_items enable row level security;
grant select, insert, update, delete on public.clothing_items to authenticated;

drop policy if exists "Household members can read clothing" on public.clothing_items;
create policy "Household members can read clothing"
  on public.clothing_items
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

drop policy if exists "Household members can add clothing" on public.clothing_items;
create policy "Household members can add clothing"
  on public.clothing_items
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

drop policy if exists "Household members can update clothing" on public.clothing_items;
create policy "Household members can update clothing"
  on public.clothing_items
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

drop policy if exists "Household members can delete clothing" on public.clothing_items;
create policy "Household members can delete clothing"
  on public.clothing_items
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

insert into public.clothing_items (id, name, detail, owner)
select
  garage_item->>'id',
  garage_item->>'name',
  coalesce(garage_item->>'detail', ''),
  case
    when garage_item->>'owner' in ('Ernest', 'Queralt', 'Dani', 'Estel') then garage_item->>'owner'
    else null
  end
from public.household_data as household
cross join lateral jsonb_array_elements(coalesce(household.items->'garatge', '[]'::jsonb)) as garage(garage_item)
where garage_item->>'garageType' = 'roba'
  and garage_item->>'id' is not null
  and garage_item->>'name' is not null
on conflict (id) do nothing;

update public.household_data as household
set items = jsonb_set(
  household.items,
  '{garatge}',
  coalesce((
    select jsonb_agg(garage_item order by ordinal)
    from jsonb_array_elements(coalesce(household.items->'garatge', '[]'::jsonb)) with ordinality as garage(garage_item, ordinal)
    where garage_item->>'garageType' is distinct from 'roba'
      or garage_item->>'id' is null
      or garage_item->>'name' is null
  ), '[]'::jsonb),
  true
),
updated_at = now()
where exists (
  select 1
  from jsonb_array_elements(coalesce(household.items->'garatge', '[]'::jsonb)) as garage(garage_item)
  where garage_item->>'garageType' = 'roba'
    and garage_item->>'id' is not null
    and garage_item->>'name' is not null
);

insert into storage.buckets (id, name, public)
values ('ourhouse-pdfs', 'ourhouse-pdfs', false)
on conflict (id) do update set public = false;

drop policy if exists "Household members can read PDFs" on storage.objects;
create policy "Household members can read PDFs"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'ourhouse-pdfs'
    and exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

drop policy if exists "Household members can upload PDFs" on storage.objects;
create policy "Household members can upload PDFs"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'ourhouse-pdfs'
    and exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

drop policy if exists "Household members can update PDFs" on storage.objects;
create policy "Household members can update PDFs"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'ourhouse-pdfs'
    and exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'ourhouse-pdfs'
    and exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );

drop policy if exists "Household members can delete PDFs" on storage.objects;
create policy "Household members can delete PDFs"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'ourhouse-pdfs'
    and exists (
      select 1
      from public.household_members
      where user_id = auth.uid()
    )
  );
