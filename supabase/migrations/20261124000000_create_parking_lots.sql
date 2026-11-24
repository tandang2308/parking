-- US-1.2 / SPEC-001 §5 — parking_lots table, spatial index, public read RLS, nearby_lots RPC
-- Data model: docs/03-architecture/architecture.md §3 · Decision: ADR-0007

create extension if not exists postgis with schema extensions;

create table public.parking_lots (
  id                uuid primary key default gen_random_uuid(),
  name              text not null check (length(trim(name)) > 0),
  location          extensions.geography(Point, 4326) not null,
  address           text,
  vehicle_types     text[] not null
                      check (cardinality(vehicle_types) > 0
                             and vehicle_types <@ array['motorbike', 'car']::text[]),
  price_motorbike   integer check (price_motorbike >= 0),   -- VND per visit
  price_car         integer check (price_car >= 0),         -- VND per visit
  opening_hours     jsonb,                                   -- format defined in SPEC-003
  capacity          integer check (capacity >= 0),
  source            text not null default 'survey'
                      check (source in ('osm', 'survey', 'owner')),
  osm_id            text unique,                             -- for US-4.1 OSM import
  is_verified       boolean not null default false,
  last_verified_at  timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.parking_lots is 'Parking lots (bãi giữ xe). See SPEC-001, architecture.md §3.';

create index parking_lots_location_gix on public.parking_lots using gist (location);

-- keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger parking_lots_set_updated_at
  before update on public.parking_lots
  for each row execute function public.set_updated_at();

-- RLS: everyone can read lots; writes only via admin (Supabase Studio / service role) for now.
-- Owner write policies come with SPEC-006.
alter table public.parking_lots enable row level security;

create policy "lots_public_read" on public.parking_lots
  for select to anon, authenticated using (true);

-- RPC: nearest lots around a point (SPEC-001 §5, BR-1, BR-2)
-- Coordinates are parameters only — never stored (BR-10, PDPL).
create or replace function public.nearby_lots(
  lat double precision,
  lng double precision,
  radius_m integer default 1000,
  vehicle_type text default null
) returns table (
  id uuid,
  name text,
  address text,
  lot_lat double precision,
  lot_lng double precision,
  vehicle_types text[],
  is_verified boolean,
  distance_m integer
)
language sql stable security invoker
set search_path = public, extensions
as $$
  with p as (
    select st_setsrid(st_makepoint(lng, lat), 4326)::geography as g   -- lng first
  )
  select l.id, l.name, l.address,
         st_y(l.location::geometry), st_x(l.location::geometry),
         l.vehicle_types, l.is_verified,
         round(st_distance(l.location, p.g))::int as distance_m
  from public.parking_lots l, p
  where st_dwithin(l.location, p.g, least(greatest(radius_m, 100), 5000))
    and (vehicle_type is null or vehicle_type = any(l.vehicle_types))
  order by distance_m asc, l.id asc
  limit 50;
$$;

revoke execute on function public.nearby_lots(double precision, double precision, integer, text) from public;
grant execute on function public.nearby_lots(double precision, double precision, integer, text) to anon, authenticated;
