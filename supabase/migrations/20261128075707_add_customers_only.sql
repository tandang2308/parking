-- Task #39 / SPEC-001 v0.4 BR-16 + §5 Data & API — customer-only lots (OSM access=customers)
-- Adds parking_lots.customers_only and returns it from nearby_lots. Decision: ADR-0007 (new migration,
-- never edit applied ones). Coordinates stay RPC parameters only — never stored (BR-10, PDPL).

-- 1. Column (constant default: existing rows get false without a table rewrite)
alter table public.parking_lots
  add column customers_only boolean not null default false;

comment on column public.parking_lots.customers_only is
  'true = parking only for customers of a shop/hotel/restaurant (OSM access=customers). SPEC-001 BR-16.';

-- 2. RPC: the return type changes (new output column), so drop + create (create or replace cannot).
drop function if exists public.nearby_lots(double precision, double precision, integer, text);

create function public.nearby_lots(
  lat double precision,
  lng double precision,
  radius_m integer default 1000,
  vehicle_type text default null          -- 'motorbike' | 'car' | null = all
) returns table (
  id uuid,
  name text,
  address text,
  lot_lat double precision,
  lot_lng double precision,
  vehicle_types text[],
  is_verified boolean,
  customers_only boolean,                 -- v0.4, BR-16
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
         l.vehicle_types, l.is_verified, l.customers_only,
         round(st_distance(l.location, p.g))::int as distance_m
  from public.parking_lots l, p
  where st_dwithin(l.location, p.g, least(greatest(radius_m, 100), 5000))
    and (vehicle_type is null or vehicle_type = any(l.vehicle_types))
  order by distance_m asc, l.id asc
  limit 50;
$$;

comment on function public.nearby_lots(double precision, double precision, integer, text) is
  'Nearest parking lots around a point (SPEC-001 §5, BR-1, BR-2, BR-16). Input coordinates are never stored.';

-- 3. Privileges: a new function gets EXECUTE for PUBLIC by default and the cloud does not
--    auto-grant to the API roles, so make them explicit again (same as 20261124000000).
revoke execute on function public.nearby_lots(double precision, double precision, integer, text) from public;
grant execute on function public.nearby_lots(double precision, double precision, integer, text) to anon, authenticated;

-- 4. Table privileges unchanged: the table-level SELECT grant (20261124010000) covers the new column;
--    RLS policy lots_public_read (select only) still applies. No new write access.
