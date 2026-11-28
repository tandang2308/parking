-- Task #39 / SPEC-001 v0.4 BR-16 + §5 — pgTAP tests for parking_lots.customers_only and nearby_lots output
-- Run locally: npx supabase test db   (never against the cloud project)
-- Fixtures are inserted inside this transaction and rolled back at the end.

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(26);

-- ---------------------------------------------------------------------------
-- Column definition
-- ---------------------------------------------------------------------------
select has_column('public', 'parking_lots', 'customers_only', 'parking_lots.customers_only exists');
select col_type_is('public', 'parking_lots', 'customers_only', 'boolean', 'customers_only is boolean');
select col_not_null('public', 'parking_lots', 'customers_only', 'customers_only is NOT NULL');
select col_has_default('public', 'parking_lots', 'customers_only', 'customers_only has a default');
select col_default_is('public', 'parking_lots', 'customers_only', 'false', 'customers_only defaults to false');

-- ---------------------------------------------------------------------------
-- QA seed (supabase/seed.sql, loaded by db reset): TC-1.2.34 entry criterion
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(name) from nearby_lots(10.3460, 107.0740) where customers_only),
  array['TEST Bãi Trước chỉ khách']::text[],
  'seed: exactly one customer-only TEST lot within 1000 m of MP-1'
);
select ok(
  exists (select 1 from nearby_lots(10.3460, 107.0740) where not customers_only),
  'seed: MP-1 also has lots with customers_only = false'
);

-- ---------------------------------------------------------------------------
-- Fixtures (isolated from seed data; rolled back)
-- ---------------------------------------------------------------------------
delete from public.parking_lots;

insert into public.parking_lots (id, name, location, vehicle_types)
values ('00000000-0000-0000-0000-0000000000d0', 'Default lot',
        st_setsrid(st_makepoint(107.0741, 10.3461), 4326)::geography, '{car}');

insert into public.parking_lots (id, name, location, vehicle_types, customers_only)
values ('00000000-0000-0000-0000-0000000000c1', 'Customer lot',
        st_setsrid(st_makepoint(107.0745, 10.3465), 4326)::geography, '{motorbike,car}', true);

select is((select customers_only from public.parking_lots where id = '00000000-0000-0000-0000-0000000000d0'),
          false, 'insert without customers_only stores false');
select throws_ok(
  $$insert into public.parking_lots (name, location, vehicle_types, customers_only)
    values ('x', st_setsrid(st_makepoint(107.07, 10.34), 4326)::geography, '{car}', null)$$,
  '23502', null, 'customers_only = null rejected');

-- ---------------------------------------------------------------------------
-- nearby_lots output (SPEC-001 §5)
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(u.n::text order by u.i)
   from pg_proc p, unnest(p.proargnames, p.proargmodes) with ordinality as u(n, m, i)
   where p.oid = 'public.nearby_lots(double precision, double precision, integer, text)'::regprocedure
     and u.m = 't'),
  array['id', 'name', 'address', 'lot_lat', 'lot_lng', 'vehicle_types', 'is_verified', 'customers_only', 'distance_m'],
  'nearby_lots output columns are in the SPEC-001 §5 order'
);
select is(
  (select format_type(u.t, null)
   from pg_proc p, unnest(p.proargnames, p.proallargtypes, p.proargmodes) as u(n, t, m)
   where p.oid = 'public.nearby_lots(double precision, double precision, integer, text)'::regprocedure
     and u.m = 't' and u.n = 'customers_only'),
  'boolean',
  'nearby_lots.customers_only is boolean'
);
select is((select customers_only from nearby_lots(10.3460, 107.0740) where id = '00000000-0000-0000-0000-0000000000c1'),
          true, 'nearby_lots returns customers_only = true for the customer-only lot');
select is((select customers_only from nearby_lots(10.3460, 107.0740) where id = '00000000-0000-0000-0000-0000000000d0'),
          false, 'nearby_lots returns customers_only = false for a default lot');
select is((select count(*)::int from nearby_lots(10.3460, 107.0740)), 2,
  'customer-only lots are kept in the result (not filtered out, BR-16)');
select is((select count(*)::int from nearby_lots(10.3460, 107.0740, 1000, 'motorbike')), 1,
  'vehicle_type filter still works with the new column');
select is(
  (select jsonb_typeof(to_jsonb(t) -> 'customers_only') from nearby_lots(10.3460, 107.0740) t
   where id = '00000000-0000-0000-0000-0000000000c1'),
  'boolean',
  'JSON row has key "customers_only" with a JSON boolean (shape PostgREST returns)'
);

-- ---------------------------------------------------------------------------
-- Function definition and privileges (re-created function must keep them)
-- ---------------------------------------------------------------------------
select ok(
  (select not prosecdef and provolatile = 's'
          and proconfig @> array['search_path=public, extensions']
   from pg_proc where oid = 'public.nearby_lots(double precision, double precision, integer, text)'::regprocedure),
  'nearby_lots is still security invoker, stable, with fixed search_path');
select ok(has_function_privilege('anon', 'public.nearby_lots(double precision, double precision, integer, text)', 'EXECUTE'),
  'anon can EXECUTE nearby_lots');
select ok(has_function_privilege('authenticated', 'public.nearby_lots(double precision, double precision, integer, text)', 'EXECUTE'),
  'authenticated can EXECUTE nearby_lots');
select ok(
  not exists (select 1 from pg_proc p, aclexplode(p.proacl) a
              where p.oid = 'public.nearby_lots(double precision, double precision, integer, text)'::regprocedure
                and a.grantee = 0 and a.privilege_type = 'EXECUTE'),
  'PUBLIC has no EXECUTE on nearby_lots');
select is((select count(*)::int from pg_proc where proname = 'nearby_lots' and pronamespace = 'public'::regnamespace),
  1, 'exactly one nearby_lots function (old signature dropped, no overload)');

-- ---------------------------------------------------------------------------
-- As app roles: read customers_only, cannot change it
-- ---------------------------------------------------------------------------
set local role anon;
select is((select customers_only from nearby_lots(10.3460, 107.0740) where id = '00000000-0000-0000-0000-0000000000c1'),
          true, 'anon: nearby_lots returns customers_only');
select is((select customers_only from public.parking_lots where id = '00000000-0000-0000-0000-0000000000c1'),
          true, 'anon: can SELECT customers_only from the table');
select throws_ok($$update public.parking_lots set customers_only = false$$, '42501', null,
  'anon: UPDATE of customers_only denied');
reset role;

set local role authenticated;
select is((select customers_only from nearby_lots(10.3460, 107.0740) where id = '00000000-0000-0000-0000-0000000000c1'),
          true, 'authenticated: nearby_lots returns customers_only');
select throws_ok($$update public.parking_lots set customers_only = false$$, '42501', null,
  'authenticated: UPDATE of customers_only denied');
reset role;

select * from finish();
rollback;
