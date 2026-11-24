-- US-1.2 / SPEC-001 §5 / TC-1.2.8 — pgTAP tests for public.parking_lots and public.nearby_lots
-- Run locally: npx supabase test db   (never against the cloud project)
-- All fixture data is inserted inside this transaction and rolled back at the end.

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(59);

-- ---------------------------------------------------------------------------
-- Fixtures
-- Centre C = Bãi Trước (10.3460, 107.0740). Lots placed with ST_Project at known
-- distances due north (azimuth 0), so expected distances are computed by PostGIS.
-- ---------------------------------------------------------------------------
delete from public.parking_lots;   -- isolate from any seed data (rolled back)

create temp table fx_center on commit drop as
  select st_setsrid(st_makepoint(107.0740, 10.3460), 4326)::geography as g;

insert into public.parking_lots (id, name, location, vehicle_types)
select v.id::uuid, v.name, st_project((select g from fx_center), v.dist, 0)::geography, v.vt::text[]
from (values
  ('00000000-0000-0000-0000-00000000000e', 'E 80m both',        80, '{motorbike,car}'),
  ('00000000-0000-0000-0000-00000000000a', 'A 200m both',      200, '{motorbike,car}'),
  ('00000000-0000-0000-0000-000000000072', 'T2 300m tie',      300, '{motorbike}'),
  ('00000000-0000-0000-0000-000000000071', 'T1 300m tie',      300, '{motorbike}'),
  ('00000000-0000-0000-0000-00000000000b', 'B 500m motorbike', 500, '{motorbike}'),
  ('00000000-0000-0000-0000-00000000000c', 'C 900m car',       900, '{car}'),
  ('00000000-0000-0000-0000-00000000000d', 'D 1100m both',    1100, '{motorbike,car}'),
  ('00000000-0000-0000-0000-00000000000f', 'F 4900m car',     4900, '{car}'),
  ('00000000-0000-0000-0000-000000000006', 'G 5200m both',    5200, '{motorbike,car}')
) as v(id, name, dist, vt);

-- Bãi Sau as an exact point, to check lot_lat / lot_lng
insert into public.parking_lots (id, name, location, vehicle_types, address)
values ('00000000-0000-0000-0000-0000000000b5', 'Bai Sau',
        st_setsrid(st_makepoint(107.0960, 10.3440), 4326)::geography, '{motorbike}', 'Thuy Van');

-- 60 lots around a far-away centre (> 5 km from C) for the limit test: 10 m apart
insert into public.parking_lots (name, location, vehicle_types)
select 'Far ' || i,
       st_project(st_setsrid(st_makepoint(107.2000, 10.5000), 4326)::geography, i * 10, 0)::geography,
       '{car}'
from generate_series(1, 60) as i;

-- ---------------------------------------------------------------------------
-- Ordering + tie-break (default radius 1000 m)
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(id order by ord) from nearby_lots(10.3460, 107.0740) with ordinality as t(id, name, address, lot_lat, lot_lng, vehicle_types, is_verified, distance_m, ord)),
  array['00000000-0000-0000-0000-00000000000e',
        '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-000000000071',
        '00000000-0000-0000-0000-000000000072',
        '00000000-0000-0000-0000-00000000000b',
        '00000000-0000-0000-0000-00000000000c']::uuid[],
  'default call returns lots within 1000 m ordered by distance, ties broken by id asc'
);

select ok(
  (select bool_and(d_prev <= distance_m)
   from (select distance_m, lag(distance_m) over (order by ord) as d_prev
         from nearby_lots(10.3460, 107.0740, 5000) with ordinality as t(id, name, address, lot_lat, lot_lng, vehicle_types, is_verified, distance_m, ord)) s
   where d_prev is not null),
  'distance_m is non-decreasing in result order (radius 5000)'
);

select is(
  (select array_agg(distance_m order by distance_m) from nearby_lots(10.3460, 107.0740) where id in (
     '00000000-0000-0000-0000-000000000071', '00000000-0000-0000-0000-000000000072')),
  array[300, 300],
  'tie lots have identical distance_m (so the id tie-break is what orders them)'
);

select is(
  (select count(*)::int from nearby_lots(10.3460, 107.0740) n
   join public.parking_lots l using (id)
   where n.distance_m <> round(st_distance(l.location, (select g from fx_center)))::int),
  0,
  'distance_m equals round(ST_Distance) computed by PostGIS for every row'
);

select ok(
  (select distance_m between 79 and 81 from nearby_lots(10.3460, 107.0740)
   where id = '00000000-0000-0000-0000-00000000000e'),
  'distance_m of the 80 m lot is ~80'
);

-- ---------------------------------------------------------------------------
-- Default radius = 1000 m
-- ---------------------------------------------------------------------------
select is((select count(*)::int from nearby_lots(10.3460, 107.0740)), 6,
  'default radius returns exactly the 6 lots within 1000 m');
select is((select count(*)::int from nearby_lots(10.3460, 107.0740, 1000)), 6,
  'explicit radius 1000 equals default');
select ok(not exists (select 1 from nearby_lots(10.3460, 107.0740)
                      where id = '00000000-0000-0000-0000-00000000000d'),
  'lot at 1100 m excluded with default radius');
select ok(exists (select 1 from nearby_lots(10.3460, 107.0740, 1200)
                  where id = '00000000-0000-0000-0000-00000000000d'),
  'lot at 1100 m included with radius 1200');
select ok((select max(distance_m) <= 1000 from nearby_lots(10.3460, 107.0740)),
  'no row beyond 1000 m with default radius');

-- ---------------------------------------------------------------------------
-- Radius clamp [100, 5000]
-- ---------------------------------------------------------------------------
select is((select array_agg(id) from nearby_lots(10.3460, 107.0740, 50)),
  array['00000000-0000-0000-0000-00000000000e']::uuid[],
  'radius 50 is clamped up to 100 (80 m lot returned)');
select is((select array_agg(id) from nearby_lots(10.3460, 107.0740, 0)),
  array['00000000-0000-0000-0000-00000000000e']::uuid[],
  'radius 0 is clamped up to 100');
select is((select array_agg(id) from nearby_lots(10.3460, 107.0740, -500)),
  array['00000000-0000-0000-0000-00000000000e']::uuid[],
  'negative radius is clamped up to 100');
select is((select array_agg(id) from nearby_lots(10.3460, 107.0740, 100)),
  array['00000000-0000-0000-0000-00000000000e']::uuid[],
  'radius 100 (lower bound) returns only the 80 m lot');
select ok(exists (select 1 from nearby_lots(10.3460, 107.0740, 5000)
                  where id = '00000000-0000-0000-0000-00000000000f'),
  'radius 5000 includes lot at 4900 m');
select ok(not exists (select 1 from nearby_lots(10.3460, 107.0740, 5000)
                      where id = '00000000-0000-0000-0000-000000000006'),
  'radius 5000 excludes lot at 5200 m');
select ok(not exists (select 1 from nearby_lots(10.3460, 107.0740, 10000)
                      where id = '00000000-0000-0000-0000-000000000006'),
  'radius 10000 is clamped down to 5000 (5200 m lot excluded)');
select ok((select max(distance_m) <= 5000 from nearby_lots(10.3460, 107.0740, 2147483647)),
  'radius int max is clamped to 5000 and does not fail');
select is((select count(*)::int from nearby_lots(10.3460, 107.0740, 10000)),
          (select count(*)::int from nearby_lots(10.3460, 107.0740, 5000)),
  'radius 10000 returns the same set size as 5000');

-- ---------------------------------------------------------------------------
-- Limit 50
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.parking_lots where name like 'Far %'), 60,
  'fixture: 60 lots in the far cluster');
select is((select count(*)::int from nearby_lots(10.5000, 107.2000, 5000)), 50,
  'at most 50 rows returned when more than 50 lots are in range');
select is((select max(distance_m) from nearby_lots(10.5000, 107.2000, 5000)),
          (select round(st_distance(location, st_setsrid(st_makepoint(107.2000, 10.5000), 4326)::geography))::int
           from public.parking_lots where name = 'Far 50'),
  'the 50 returned rows are the nearest 50 (farthest returned = 50th lot)');

-- ---------------------------------------------------------------------------
-- vehicle_type filter
-- ---------------------------------------------------------------------------
select is((select count(*)::int from nearby_lots(10.3460, 107.0740, 1000, null)), 6,
  'vehicle_type null returns all types');
select is((select array_agg(id order by distance_m, id) from nearby_lots(10.3460, 107.0740, 1000, 'car')),
  array['00000000-0000-0000-0000-00000000000e',
        '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-00000000000c']::uuid[],
  'vehicle_type car returns only lots accepting cars');
select is((select array_agg(id order by distance_m, id) from nearby_lots(10.3460, 107.0740, 1000, 'motorbike')),
  array['00000000-0000-0000-0000-00000000000e',
        '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-000000000071',
        '00000000-0000-0000-0000-000000000072',
        '00000000-0000-0000-0000-00000000000b']::uuid[],
  'vehicle_type motorbike returns only lots accepting motorbikes');
select ok((select bool_and('car' = any(vehicle_types)) from nearby_lots(10.3460, 107.0740, 5000, 'car')),
  'every row for car filter contains car');
select is((select count(*)::int from nearby_lots(10.3460, 107.0740, 5000, 'bus')), 0,
  'unknown vehicle_type returns empty result');

-- ---------------------------------------------------------------------------
-- Returned columns
-- ---------------------------------------------------------------------------
select ok((select abs(lot_lat - 10.3440) < 1e-9 from nearby_lots(10.3460, 107.0740, 5000)
           where id = '00000000-0000-0000-0000-0000000000b5'),
  'lot_lat is the latitude (Bai Sau 10.3440)');
select ok((select abs(lot_lng - 107.0960) < 1e-9 from nearby_lots(10.3460, 107.0740, 5000)
           where id = '00000000-0000-0000-0000-0000000000b5'),
  'lot_lng is the longitude (Bai Sau 107.0960)');
select is((select distance_m from nearby_lots(10.3460, 107.0740, 5000)
           where id = '00000000-0000-0000-0000-0000000000b5'),
          (select round(st_distance(st_setsrid(st_makepoint(107.0960, 10.3440), 4326)::geography,
                                    (select g from fx_center)))::int),
  'Bai Truoc -> Bai Sau distance_m matches PostGIS');
select ok((select distance_m between 2000 and 3000 from nearby_lots(10.3460, 107.0740, 5000)
           where id = '00000000-0000-0000-0000-0000000000b5'),
  'Bai Truoc -> Bai Sau is roughly 2-3 km (sanity: lat/lng not swapped)');
select is((select row(name, address, vehicle_types, is_verified)::text from nearby_lots(10.3460, 107.0740, 5000)
           where id = '00000000-0000-0000-0000-0000000000b5'),
          row('Bai Sau'::text, 'Thuy Van'::text, '{motorbike}'::text[], false)::text,
  'name, address, vehicle_types, is_verified returned as stored');

-- ---------------------------------------------------------------------------
-- Check constraints
-- ---------------------------------------------------------------------------
select throws_ok(
  $$insert into public.parking_lots (name, location, vehicle_types)
    values ('x', st_setsrid(st_makepoint(107.07, 10.34), 4326)::geography, '{}')$$,
  '23514', null, 'empty vehicle_types rejected');
select throws_ok(
  $$insert into public.parking_lots (name, location, vehicle_types)
    values ('x', st_setsrid(st_makepoint(107.07, 10.34), 4326)::geography, '{bus}')$$,
  '23514', null, 'unknown vehicle_type rejected');
select throws_ok(
  $$insert into public.parking_lots (name, location, vehicle_types)
    values ('x', st_setsrid(st_makepoint(107.07, 10.34), 4326)::geography, '{car,bus}')$$,
  '23514', null, 'mix of valid and invalid vehicle_types rejected');
select throws_ok(
  $$insert into public.parking_lots (name, location, vehicle_types)
    values ('x', st_setsrid(st_makepoint(107.07, 10.34), 4326)::geography, null)$$,
  '23502', null, 'null vehicle_types rejected');
select throws_ok(
  $$insert into public.parking_lots (name, location, vehicle_types)
    values ('   ', st_setsrid(st_makepoint(107.07, 10.34), 4326)::geography, '{car}')$$,
  '23514', null, 'blank name rejected');
select lives_ok(
  $$insert into public.parking_lots (name, location, vehicle_types)
    values ('ok', st_setsrid(st_makepoint(106.70, 10.77), 4326)::geography, '{car,motorbike}')$$,
  'valid vehicle_types accepted');

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------
update public.parking_lots set updated_at = '2000-01-01T00:00:00Z'
 where id = '00000000-0000-0000-0000-00000000000a';  -- trigger overrides this to now()
select is((select updated_at from public.parking_lots where id = '00000000-0000-0000-0000-00000000000a'),
          now(), 'BEFORE UPDATE trigger sets updated_at = now() (overrides client value)');
select has_trigger('public', 'parking_lots', 'parking_lots_set_updated_at', 'updated_at trigger exists');

-- ---------------------------------------------------------------------------
-- RLS, grants, function definition
-- ---------------------------------------------------------------------------
select ok((select relrowsecurity from pg_class where oid = 'public.parking_lots'::regclass),
  'RLS enabled on parking_lots');
select policies_are('public', 'parking_lots', array['lots_public_read'], 'only the public read policy exists');
select policy_cmd_is('public', 'parking_lots', 'lots_public_read', 'select', 'lots_public_read is SELECT-only');
select table_privs_are('public', 'parking_lots', 'anon', array['SELECT'], 'anon has only SELECT on parking_lots');
select table_privs_are('public', 'parking_lots', 'authenticated', array['SELECT'], 'authenticated has only SELECT on parking_lots');
select ok(
  has_function_privilege('anon', 'public.nearby_lots(double precision, double precision, integer, text)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.nearby_lots(double precision, double precision, integer, text)', 'EXECUTE'),
  'anon and authenticated can EXECUTE nearby_lots');
select ok(
  not exists (select 1 from pg_proc p, aclexplode(p.proacl) a
              where p.oid = 'public.nearby_lots(double precision, double precision, integer, text)'::regprocedure
                and a.grantee = 0 and a.privilege_type = 'EXECUTE'),
  'PUBLIC has no EXECUTE on nearby_lots');
select ok(
  (select not prosecdef and provolatile = 's'
          and proconfig @> array['search_path=public, extensions']
   from pg_proc where oid = 'public.nearby_lots(double precision, double precision, integer, text)'::regprocedure),
  'nearby_lots is security invoker, stable, with fixed search_path');

-- ---------------------------------------------------------------------------
-- Behaviour as app roles (anon, authenticated)
-- ---------------------------------------------------------------------------
set local role anon;
select ok((select count(*) > 0 from public.parking_lots), 'anon: direct SELECT on parking_lots works');
select is((select count(*)::int from nearby_lots(10.3460, 107.0740)), 6, 'anon: nearby_lots returns rows');
select throws_ok(
  $$insert into public.parking_lots (name, location, vehicle_types)
    values ('x', st_setsrid(st_makepoint(107.07, 10.34), 4326)::geography, '{car}')$$,
  '42501', null, 'anon: INSERT denied');
select throws_ok($$update public.parking_lots set name = 'hacked'$$, '42501', null, 'anon: UPDATE denied');
select throws_ok($$delete from public.parking_lots$$, '42501', null, 'anon: DELETE denied');
reset role;

set local role authenticated;
select ok((select count(*) > 0 from public.parking_lots), 'authenticated: direct SELECT on parking_lots works');
select is((select count(*)::int from nearby_lots(10.3460, 107.0740, 1000, 'car')), 3, 'authenticated: nearby_lots returns rows');
select throws_ok(
  $$insert into public.parking_lots (name, location, vehicle_types)
    values ('x', st_setsrid(st_makepoint(107.07, 10.34), 4326)::geography, '{car}')$$,
  '42501', null, 'authenticated: INSERT denied');
select throws_ok($$update public.parking_lots set name = 'hacked'$$, '42501', null, 'authenticated: UPDATE denied');
select throws_ok($$delete from public.parking_lots$$, '42501', null, 'authenticated: DELETE denied');
reset role;

select is((select count(*)::int from public.parking_lots where name = 'hacked'), 0, 'no row was modified by app roles');

select * from finish();
rollback;
