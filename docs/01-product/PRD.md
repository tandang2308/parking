# PRD — ParkFinder Vung Tau (MVP)

| Field | Value |
|---|---|
| Status | Draft |
| Version | 0.1 |
| Owner | Product Owner |
| Last updated | 2026-11-24 |
| Related | [Backlog](backlog.md) · [Roadmap](roadmap.md) · [ADR log](../03-architecture/adr/README.md) |

## 1. Problem
Drivers in Vũng Tàu — especially tourists arriving by car from HCMC on weekends/holidays — cannot easily find where to park, how much it costs, or whether a lot is full. Most parking lots are not listed (or listed wrongly) on existing map apps.

## 2. Vision
"Open the app, see the nearest suitable parking lot, and drive there."

## 3. Target users
| Persona | Needs |
|---|---|
| **Tourist driver (car)** | Find car parking near beaches/attractions, know the price upfront |
| **Local motorbike rider** | Quick nearby motorbike parking, price, opening hours |
| **Parking lot owner** | Get more customers; keep lot info and availability up to date |
| **Admin (our team)** | Keep data accurate; verify owners |

## 4. MVP scope (in)
| Epic | Summary |
|---|---|
| E1 Location & Map | Show current position and nearby lots on map |
| E2 Search & Filter | Filter by vehicle type (motorbike/car), open now, price; list sorted by distance |
| E3 Lot Details | Price, hours, photos, capacity, "Navigate" (deep link to Google/Apple Maps) |
| E4 Admin & Data | Managed via Supabase Studio in MVP ([ADR-0003](../03-architecture/adr/ADR-0003-supabase-studio-as-admin.md)) |
| E5 Platform | Vietnamese + English, location consent & privacy policy (PDPL) |
| E6 Owner Portal | Free owner registration, claim/verify lot, edit info, live availability toggle ([ADR-0004](../03-architecture/adr/ADR-0004-owner-registration-free-first.md)) |

## 5. Out of scope (MVP) — future backlog
- E7 Monetization (featured listing, freemium, commission)
- Online booking & payment (VietQR / MoMo / ZaloPay / VNPay)
- Reviews & ratings
- Other cities (Đà Lạt, Nha Trang, HCMC center)
- Dedicated admin web panel
- App Store / Play Store release (MVP beta = Android via Firebase App Distribution + Web)

## 6. Constraints
- **Zero cost for MVP** ([ADR-0002](../03-architecture/adr/ADR-0002-zero-cost-mvp-stack.md)).
- **Legal:** Vietnam Personal Data Protection Law (effective 01/01/2026) — location is personal data → explicit consent + privacy policy.
- Charging owners requires a registered business entity + e-invoicing → deferred.

## 7. Success metrics (beta)
| Metric | Target |
|---|---|
| Lots in database (Vũng Tàu) | ≥ 150 |
| Lots verified ("last verified" < 30 days) | ≥ 70% |
| Registered owners | ≥ 20 |
| Beta weekly active users | ≥ 300 |
| "Navigate" taps / session | ≥ 0.5 |

## 8. Risks
| Risk | Mitigation |
|---|---|
| Stale / wrong data | "Last verified" date, owner self-updates, user reports (later) |
| Fake owner claims | Document + photo verification, admin approval, on-site visit if needed |
| Poor GPS in small alleys | Allow user to adjust pin manually |
| Free-tier limits (Supabase pause; tile provider without SLA) | Keep-alive job; tile provider in config with fallbacks (ADR-0009) |
| Owners unwilling to pay later | Prove value with traffic stats before charging |

## 9. Change history
| Version | Date | Change | By |
|---|---|---|---|
| 0.1 | 2026-11-24 | Initial draft from kickoff discussion | PO |
