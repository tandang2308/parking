-- US-1.2 / SPEC-001: explicit table privileges for the Data API.
-- Cloud projects do not auto-grant table privileges to anon/authenticated (local stack does),
-- so nearby_lots (security invoker) failed with 42501 in the cloud. Make privileges explicit
-- and identical in local and cloud: read-only for app roles; RLS still applies on top.
revoke all on table public.parking_lots from anon, authenticated;
grant select on table public.parking_lots to anon, authenticated;
