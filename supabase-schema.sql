create table if not exists public.customers (
  id text primary key,
  nama text not null,
  hp text not null unique,
  password text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id text primary key,
  customer_id text,
  status text not null default 'masuk',
  created_at timestamptz not null default now(),
  data jsonb not null
);

create index if not exists orders_customer_id_idx on public.orders (customer_id);
create index if not exists orders_status_idx on public.orders (status);
create index if not exists orders_created_at_idx on public.orders (created_at);

alter table public.customers enable row level security;
alter table public.orders enable row level security;

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
