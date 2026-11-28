-- A5 (MTG-2026-11-24-po-decisions) / Q-QA-3 — QA seed data, LOCAL ONLY.
-- Spec: SPEC-001 §8 "Test notes" (mock GPS points MP-1..MP-7, test data rules).
-- Loaded by `npx supabase db reset` via config.toml [db.seed]. NEVER push to the cloud project.
--
-- All lots are fake: name starts with "TEST ", osm_id is null, source = 'survey'.
-- Positions are deterministic (ST_Project from a mock point; no random()).
--
-- Guarantees (checked by the queries at the bottom of this comment):
--   MP-2 Bãi Sau (10.3440, 107.0960): >= 60 lots within 600 m, mix of motorbike / car / both,
--        incl. 2 lots with identical coordinates (spiderfy, US-1.2 AC7)
--   MP-5 offshore (10.3400, 107.1150): 0 lots within 1 km, >= 1 within 3 km (MP-2 cluster is ~1.5–2.7 km away)
--   MP-7 NW corner (10.4400, 107.0400): 0 lots within 3 km
--   MP-1, MP-3, MP-4: a few lots each so pins appear at those points
--   MP-1: exactly one lot with customers_only = true ("TEST Bãi Trước chỉ khách", BR-16, TC-1.2.34)
--
-- Check after seeding:
--   select count(*) from nearby_lots(10.3440, 107.0960, 1000);   -- MP-2: 50 (capped, >= 60 in range)
--   select count(*) from nearby_lots(10.3400, 107.1150, 1000);   -- MP-5: 0
--   select count(*) from nearby_lots(10.3400, 107.1150, 3000);   -- MP-5: >= 1
--   select count(*) from nearby_lots(10.4400, 107.0400, 3000);   -- MP-7: 0
--   select name from nearby_lots(10.3460, 107.0740) where customers_only;   -- MP-1: TEST Bãi Trước chỉ khách

set search_path = public, extensions;

-- MP-2 Bãi Sau: 64 lots on a sunflower spiral, radius up to ~600 m.
-- vehicle types cycle motorbike / car / both; prices and capacity vary; every 4th lot verified.
insert into public.parking_lots
  (name, location, address, vehicle_types, price_motorbike, price_car, capacity, source, is_verified, last_verified_at)
select
  'TEST Bãi Sau ' || lpad(i::text, 2, '0'),
  st_project(st_setsrid(st_makepoint(107.0960, 10.3440), 4326)::geography,
             75 * sqrt(i),                       -- 75 m .. 600 m
             radians((i * 137.508)::numeric % 360))::geography,
  'TEST ' || i || ' Thùy Vân, Vũng Tàu',
  case i % 3 when 0 then '{motorbike}' when 1 then '{car}' else '{motorbike,car}' end::text[],
  case when i % 3 in (0, 2) then 5000 + (i % 3) * 1000 end,
  case when i % 3 in (1, 2) then 20000 + (i % 5) * 5000 end,
  case when i % 7 = 0 then null else 20 + i end,
  'survey',
  i % 4 = 0,
  case when i % 4 = 0 then timestamptz '2026-11-01 09:00+07' end
from generate_series(1, 64) as i;

-- MP-2: two lots with identical coordinates (spiderfy, US-1.2 AC7)
insert into public.parking_lots (name, location, address, vehicle_types, price_motorbike, source)
values
  ('TEST Bãi Sau trùng toạ độ A', st_setsrid(st_makepoint(107.0965, 10.3445), 4326)::geography,
   'TEST Thùy Vân', '{motorbike}', 5000, 'survey'),
  ('TEST Bãi Sau trùng toạ độ B', st_setsrid(st_makepoint(107.0965, 10.3445), 4326)::geography,
   'TEST Thùy Vân', '{car}', null, 'survey');

-- MP-1 Bãi Trước (default centre): 8 lots within ~400 m
insert into public.parking_lots (name, location, vehicle_types, price_motorbike, price_car, source)
select
  'TEST Bãi Trước ' || i,
  st_project(st_setsrid(st_makepoint(107.0740, 10.3460), 4326)::geography, 50 * i, radians(i * 45))::geography,
  case i % 3 when 0 then '{motorbike}' when 1 then '{car}' else '{motorbike,car}' end::text[],
  case when i % 3 <> 1 then 5000 end,
  case when i % 3 <> 0 then 30000 end,
  'survey'
from generate_series(1, 8) as i;

-- MP-1: one customer-only lot (SPEC-001 v0.4 BR-16, TC-1.2.34), 120 m from MP-1.
-- All other TEST lots keep the default customers_only = false (e.g. "TEST Bãi Trước 1" as the counterpart).
insert into public.parking_lots (name, location, address, vehicle_types, price_motorbike, price_car, source, customers_only)
values
  ('TEST Bãi Trước chỉ khách',
   st_project(st_setsrid(st_makepoint(107.0740, 10.3460), 4326)::geography, 120, radians(200))::geography,
   'TEST Thùy Vân (khách của cửa hàng)', '{motorbike,car}', 5000, 30000, 'survey', true);

-- MP-3 Tượng Chúa Kitô: 3 lots; MP-4 Chợ Vũng Tàu: 4 lots
insert into public.parking_lots (name, location, vehicle_types, source)
select 'TEST Chúa Kitô ' || i,
       st_project(st_setsrid(st_makepoint(107.0845, 10.3265), 4326)::geography, 120 * i, radians(i * 120))::geography,
       '{motorbike}', 'survey'
from generate_series(1, 3) as i;

insert into public.parking_lots (name, location, vehicle_types, source)
select 'TEST Chợ Vũng Tàu ' || i,
       st_project(st_setsrid(st_makepoint(107.0820, 10.3500), 4326)::geography, 80 * i, radians(i * 90))::geography,
       case when i % 2 = 0 then '{motorbike}' else '{motorbike,car}' end::text[],
       'survey'
from generate_series(1, 4) as i;

reset search_path;
