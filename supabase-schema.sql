create extension if not exists pgcrypto;

-- Multi-laundry master data
create table if not exists public.laundries (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  logo_url text,
  primary_color text default '#00AED6',
  secondary_color text,
  phone text,
  address text,
  tagline text,
  is_active boolean default true,
  plan text default 'free',
  created_at timestamptz default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  laundry_id uuid references public.laundries(id),
  name text not null,
  type text not null,
  price_per_kg numeric not null,
  icon text,
  sort_order int default 0,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists public.laundry_users (
  id uuid primary key default gen_random_uuid(),
  laundry_id uuid references public.laundries(id),
  name text not null,
  phone text,
  email text,
  password text,
  role text not null default 'owner',
  is_active boolean default true,
  created_at timestamptz default now()
);

-- Existing app-compatible customers table.
create table if not exists public.customers (
  id text primary key,
  laundry_id uuid references public.laundries(id),
  nama text not null,
  hp text not null,
  phone text,
  password text not null,
  created_at timestamptz not null default now()
);

-- Existing app-compatible orders table.
create table if not exists public.orders (
  id text primary key,
  laundry_id uuid references public.laundries(id),
  customer_id text,
  status text not null default 'masuk',
  created_at timestamptz not null default now(),
  data jsonb not null
);

-- Safe migration for older single-laundry installs.
alter table public.customers add column if not exists laundry_id uuid references public.laundries(id);
alter table public.customers add column if not exists phone text;
alter table public.orders add column if not exists laundry_id uuid references public.laundries(id);

update public.customers
set phone = coalesce(phone, hp)
where phone is null;

-- Helpful indexes.
create index if not exists laundries_slug_idx on public.laundries (slug);
create index if not exists services_laundry_id_idx on public.services (laundry_id);
create index if not exists customers_laundry_id_idx on public.customers (laundry_id);
create index if not exists orders_laundry_id_idx on public.orders (laundry_id);
create index if not exists orders_customer_id_idx on public.orders (customer_id);
create index if not exists orders_status_idx on public.orders (status);
create index if not exists orders_created_at_idx on public.orders (created_at);
create index if not exists laundry_users_laundry_id_idx on public.laundry_users (laundry_id);

-- Remove old global phone uniqueness if it exists, then use tenant-scoped uniqueness.
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.customers'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) in ('UNIQUE (hp)', 'UNIQUE (phone)')
  loop
    execute format('alter table public.customers drop constraint if exists %I', c.conname);
  end loop;
end $$;

create unique index if not exists customers_laundry_phone_unique
on public.customers (laundry_id, phone);

-- Seed laundries.
insert into public.laundries (slug, name, primary_color, secondary_color, phone, address, tagline, is_active, plan)
values
  ('bersih-wangi', 'Bersih Wangi Laundry', '#00AED6', '#0090B0', null, null, 'Laundry kiloan bersih, wangi, dan transparan', true, 'free'),
  ('queen-laundry', 'Queen Laundry', '#8B5CF6', '#6D28D9', null, null, 'Layanan laundry praktis untuk pelanggan setia', true, 'free')
on conflict (slug) do update set
  name = excluded.name,
  primary_color = excluded.primary_color,
  secondary_color = excluded.secondary_color,
  tagline = excluded.tagline,
  is_active = excluded.is_active,
  plan = excluded.plan;

-- Seed 4 default services for each sample laundry.
insert into public.services (laundry_id, name, type, price_per_kg, icon, sort_order, is_active)
select l.id, s.name, s.type, s.price_per_kg, s.icon, s.sort_order, true
from public.laundries l
cross join (
  values
    ('Cuci + Kering', 'cuci_kering', 7000, 'ti-wind', 1),
    ('Cuci + Setrika', 'cuci_setrika', 10000, 'ti-shirt', 2),
    ('Setrika Saja', 'setrika', 6000, 'ti-ironing', 3),
    ('Ekspres', 'ekspres', 15000, 'ti-bolt', 4)
) as s(name, type, price_per_kg, icon, sort_order)
where l.slug in ('bersih-wangi', 'queen-laundry')
  and not exists (
    select 1
    from public.services existing
    where existing.laundry_id = l.id
      and existing.type = s.type
  );

-- Backfill old rows into Bersih Wangi so existing data remains visible after tenant filtering.
update public.customers c
set laundry_id = l.id
from public.laundries l
where c.laundry_id is null
  and l.slug = 'bersih-wangi';

update public.orders o
set laundry_id = l.id,
    data = jsonb_set(
      jsonb_set(
        jsonb_set(o.data, '{laundryId}', to_jsonb(l.id::text), true),
        '{laundrySlug}', to_jsonb(l.slug), true
      ),
      '{laundryName}', to_jsonb(l.name), true
    )
from public.laundries l
where o.laundry_id is null
  and l.slug = 'bersih-wangi';

-- RLS kept permissive because this static frontend uses Supabase anon REST directly.
alter table public.laundries enable row level security;
alter table public.services enable row level security;
alter table public.laundry_users enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;

drop policy if exists "Allow public laundry access" on public.laundries;
create policy "Allow public laundry access"
on public.laundries
for all
to anon
using (true)
with check (true);

drop policy if exists "Allow public service access" on public.services;
create policy "Allow public service access"
on public.services
for all
to anon
using (true)
with check (true);

drop policy if exists "Allow public laundry user access" on public.laundry_users;
create policy "Allow public laundry user access"
on public.laundry_users
for all
to anon
using (true)
with check (true);

drop policy if exists "Allow public customer access" on public.customers;
create policy "Allow public customer access"
on public.customers
for all
to anon
using (true)
with check (true);

drop policy if exists "Allow public order access" on public.orders;
create policy "Allow public order access"
on public.orders
for all
to anon
using (true)
with check (true);
