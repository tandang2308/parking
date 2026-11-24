#!/usr/bin/env node
// US-4.1 — Import existing Vũng Tàu parking lots from OpenStreetMap (Overpass API).
// Spec refs: SPEC-001 BR-12 (service area bbox), architecture.md §3 (parking_lots), ADR-0007.
//
// Usage (Node 22+, no dependencies):
//   node supabase/scripts/import-osm.mjs            # query Overpass, write supabase/data/osm_vung_tau.sql
//   node supabase/scripts/import-osm.mjs --in r.json  # use a saved Overpass JSON response instead (offline)
//   node supabase/scripts/import-osm.mjs --save-raw r.json  # also save the raw response (outside the repo)
//
// The output is a deterministic, idempotent SQL file (insert ... on conflict (osm_id) do update).
// Apply LOCALLY only, e.g.:
//   docker exec -i supabase_db_parking psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/data/osm_vung_tau.sql
// Loading into the cloud project is a separate PO decision (run via /deploy-db process, never ad hoc).
//
// Data © OpenStreetMap contributors, licensed under ODbL 1.0 (https://www.openstreetmap.org/copyright).

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const OVERPASS_URL = 'https://overpass-api.de/api/interpreter';
const USER_AGENT = 'ParkFinder-import/0.1';
// SPEC-001 BR-12: lat 10.30–10.45, lng 107.03–107.20 (Overpass bbox order: south,west,north,east)
const BBOX = { south: 10.30, west: 107.03, north: 10.45, east: 107.20 };
const TIMEOUT_S = 90;

const here = dirname(fileURLToPath(import.meta.url));
const OUT_FILE = resolve(here, '..', 'data', 'osm_vung_tau.sql');

const bboxStr = `${BBOX.south},${BBOX.west},${BBOX.north},${BBOX.east}`;
const QUERY = `[out:json][timeout:${TIMEOUT_S}];
(
  nwr["amenity"="parking"](${bboxStr});
  nwr["amenity"="motorcycle_parking"](${bboxStr});
);
out center tags;`;

// One logical request; retried only on 429/502/503/504 (server busy) with exponential backoff,
// as the Overpass server itself asks for.
async function fetchOverpass(maxAttempts = 4) {
  let wait = 15_000;
  for (let attempt = 1; ; attempt++) {
    try {
      return await fetchOnce();
    } catch (e) {
      if (!e.retryable || attempt >= maxAttempts) throw e;
      console.error(`${e.message.split('\n')[0]} — retry ${attempt}/${maxAttempts - 1} in ${wait / 1000} s`);
      await new Promise((r) => setTimeout(r, wait));
      wait *= 2;
    }
  }
}

async function fetchOnce() {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), (TIMEOUT_S + 30) * 1000);
  try {
    const res = await fetch(OVERPASS_URL, {
      method: 'POST',
      headers: {
        'User-Agent': USER_AGENT,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: new URLSearchParams({ data: QUERY }).toString(),
      signal: ctrl.signal,
    });
    if (!res.ok) {
      const err = new Error(`Overpass HTTP ${res.status}: ${(await res.text()).slice(0, 300)}`);
      err.retryable = [429, 502, 503, 504].includes(res.status);
      throw err;
    }
    return await res.json();
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------------------
// Mapping helpers
// ---------------------------------------------------------------------------
const YES = new Set(['yes', 'designated', 'true', '1']);

function isPrivate(tags) {
  const a = (tags.access || '').toLowerCase().trim();
  if (a === 'private' || a === 'no') return a;
  return null;
}

function vehicleTypes(tags) {
  const types = new Set();
  if (tags.amenity === 'motorcycle_parking') {
    types.add('motorbike');
    return [...types];
  }
  types.add('car');
  const motorHints = [tags.motorcycle, tags.moped, tags['capacity:motorcycle'] && 'yes', tags['parking:motorcycle'] && 'yes']
    .filter(Boolean)
    .map((v) => String(v).toLowerCase());
  if (motorHints.some((v) => YES.has(v) || /^\d+$/.test(v))) types.add('motorbike');
  if (/motor|xe máy|xe may/i.test(tags.parking || '')) types.add('motorbike');
  // name hint, e.g. amenity=parking + name="Motorbike parking" / "Bãi giữ xe máy"
  if (/motorbike|motorcycle|scooter|xe máy|xe may/i.test(`${tags.name || ''} ${tags['name:vi'] || ''} ${tags['name:en'] || ''}`)) types.add('motorbike');
  // keep stable order: motorbike before car (matches array['motorbike','car'] in the schema)
  return ['motorbike', 'car'].filter((t) => types.has(t));
}

function address(tags) {
  if (tags['addr:full']) return tags['addr:full'].trim();
  const street = [tags['addr:housenumber'], tags['addr:street']].filter(Boolean).join(' ');
  const parts = [street, tags['addr:subdistrict'], tags['addr:district'], tags['addr:city']]
    .map((p) => (p || '').trim())
    .filter(Boolean);
  return parts.length ? parts.join(', ') : null;
}

function capacity(tags) {
  const c = (tags.capacity || '').trim();
  return /^\d+$/.test(c) ? parseInt(c, 10) : null;
}

// Price only when clearly parseable. Accepted forms in `charge` (or `fee` if it carries a value):
//   "5000 VND", "5,000 VND", "5.000 đ", "5000" — a single amount, no ranges/time units.
function price(tags) {
  const fee = (tags.fee || '').toLowerCase().trim();
  if (fee === 'no' || fee === 'free') return 0;
  const raw = (tags.charge || (/\d/.test(fee) ? fee : '')).trim();
  if (!raw) return null;
  const m = raw.match(/^(\d{1,3}(?:[.,]\d{3})+|\d+)\s*(vnd|vnđ|đ|d)?$/i);
  if (!m) return null;
  return parseInt(m[1].replace(/[.,]/g, ''), 10);
}

function mapElement(el, stats) {
  const tags = el.tags || {};
  const osmId = `${el.type}/${el.id}`;
  const priv = isPrivate(tags);
  if (priv) {
    stats.skipped[`access=${priv}`] = (stats.skipped[`access=${priv}`] || 0) + 1;
    return null;
  }
  const lat = el.type === 'node' ? el.lat : el.center?.lat;
  const lon = el.type === 'node' ? el.lon : el.center?.lon;
  if (typeof lat !== 'number' || typeof lon !== 'number') {
    stats.skipped['no coordinates'] = (stats.skipped['no coordinates'] || 0) + 1;
    return null;
  }
  const name = (tags.name || tags['name:vi'] || '').trim() || `Bãi đỗ xe (OSM ${osmId})`;
  const vt = vehicleTypes(tags);
  const p = price(tags);
  if (tags.fee || tags.charge) stats.feeTagged.push(`${osmId}: fee=${tags.fee ?? '-'} charge=${tags.charge ?? '-'}`);
  if (p !== null) stats.priced++;
  return {
    osmId,
    name,
    lat,
    lon,
    address: address(tags),
    vehicleTypes: vt,
    // free (0) applies to every vehicle type; a single amount only when the lot has one type
    priceMotorbike: vt.includes('motorbike') && (p === 0 || vt.length === 1) ? p : null,
    priceCar: vt.includes('car') && (p === 0 || vt.length === 1) ? p : null,
    capacity: capacity(tags),
  };
}

// ---------------------------------------------------------------------------
// SQL output
// ---------------------------------------------------------------------------
const q = (v) => (v === null || v === undefined ? 'null' : `'${String(v).replace(/'/g, "''")}'`);
const n = (v) => (v === null || v === undefined ? 'null' : String(v));
const coord = (v) => v.toFixed(7);

function toSql(rows, stats, generatedAt) {
  const byType = rows.reduce((acc, r) => {
    const k = r.vehicleTypes.join('+');
    acc[k] = (acc[k] || 0) + 1;
    return acc;
  }, {});
  const header = [
    '-- US-4.1 — OpenStreetMap parking lots for Vũng Tàu (generated by supabase/scripts/import-osm.mjs)',
    '-- Spec: SPEC-001 BR-12 (service area) · architecture.md §3 (parking_lots) · ADR-0007',
    '--',
    '-- Data © OpenStreetMap contributors, ODbL 1.0 — https://www.openstreetmap.org/copyright',
    '--',
    `-- Generated:   ${generatedAt}`,
    `-- Source:      ${OVERPASS_URL}`,
    `-- Query bbox:  lat ${BBOX.south}–${BBOX.north}, lng ${BBOX.west}–${BBOX.east} (amenity=parking | motorcycle_parking, nwr, out center tags)`,
    `-- Elements:    ${stats.total} returned · ${rows.length} rows written`,
    `-- Skipped:     ${Object.entries(stats.skipped).map(([k, v]) => `${k}: ${v}`).join(', ') || 'none'}`,
    `-- By vehicle:  ${Object.entries(byType).sort().map(([k, v]) => `${k}: ${v}`).join(', ')}`,
    '--',
    '-- Idempotent: insert ... on conflict (osm_id) do update. Rows sorted by osm_id.',
    '-- Apply to the LOCAL database only. Loading into the cloud project is a separate PO decision.',
    '',
  ].join('\n');

  if (rows.length === 0) return `${header}-- (no rows)\n`;

  const values = rows
    .map(
      (r) =>
        `  (${q(r.osmId)}, ${q(r.name)}, extensions.st_setsrid(extensions.st_makepoint(${coord(r.lon)}, ${coord(r.lat)}), 4326)::extensions.geography, ` +
        `${q(r.address)}, ${q('{' + r.vehicleTypes.join(',') + '}')}::text[], ${n(r.priceMotorbike)}, ${n(r.priceCar)}, ${n(r.capacity)}, 'osm', false, null)`,
    )
    .join(',\n');

  return `${header}
begin;

insert into public.parking_lots
  (osm_id, name, location, address, vehicle_types, price_motorbike, price_car, capacity, source, is_verified, last_verified_at)
values
${values}
on conflict (osm_id) do update set
  name            = excluded.name,
  location        = excluded.location,
  address         = excluded.address,
  vehicle_types   = excluded.vehicle_types,
  price_motorbike = excluded.price_motorbike,
  price_car       = excluded.price_car,
  capacity        = excluded.capacity,
  source          = excluded.source
where public.parking_lots.source = 'osm';   -- never overwrite lots that were re-sourced (survey/owner)

commit;
`;
}

async function main() {
  const inIdx = process.argv.indexOf('--in');
  const data = inIdx > 0 ? JSON.parse(await readFile(process.argv[inIdx + 1], 'utf8')) : await fetchOverpass();
  const rawIdx = process.argv.indexOf('--save-raw');   // debugging only; raw data is not kept in the repo
  if (rawIdx > 0) await writeFile(process.argv[rawIdx + 1], JSON.stringify(data), 'utf8');
  const elements = Array.isArray(data.elements) ? data.elements : [];
  const stats = { total: elements.length, skipped: {}, feeTagged: [], priced: 0 };

  const seen = new Set();
  const rows = [];
  for (const el of elements) {
    const r = mapElement(el, stats);
    if (!r || seen.has(r.osmId)) continue;
    seen.add(r.osmId);
    rows.push(r);
  }
  rows.sort((a, b) => (a.osmId < b.osmId ? -1 : a.osmId > b.osmId ? 1 : 0));

  // Date only (not time) + OSM base timestamp: reruns on the same data/day are byte-identical.
  const generatedAt = `${new Date().toISOString().slice(0, 10)} (OSM data as of ${data.osm3s?.timestamp_osm_base || 'unknown'})`;
  await mkdir(dirname(OUT_FILE), { recursive: true });
  await writeFile(OUT_FILE, toSql(rows, stats, generatedAt), 'utf8');

  console.log(`elements: ${stats.total}, rows: ${rows.length}, skipped: ${JSON.stringify(stats.skipped)}`);
  console.log(`fee/charge tagged: ${stats.feeTagged.length}, price parsed: ${stats.priced}`);
  for (const f of stats.feeTagged) console.log(`  ${f}`);
  console.log(`wrote ${OUT_FILE}`);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
