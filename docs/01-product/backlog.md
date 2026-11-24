# Product Backlog

> Source of truth for **content**; day-to-day status is tracked on the Jira board. Keep IDs identical in both.
> Estimates are initial (Fibonacci SP) — to be re-estimated by the team with Planning Poker.

| Status values | `New` · `Ready` · `In Sprint` · `Done` · `Dropped` |
|---|---|

## MVP

### E1 — Location & Map
| ID | User story | SP | Status | Spec |
|---|---|---|---|---|
| US-1.1 | As a driver, I want to see my current position on a map, so that I can orient myself and find parking around me | 5 | New | SPEC-001 |
| US-1.2 | As a driver, I want to see nearby parking lots as pins on the map, so that I can quickly pick the closest suitable one | 8 | New | SPEC-001 |
| US-1.3 | As a driver, I want to adjust my position manually when GPS is inaccurate, so that nearby lots and distances are correct | 3 | New | SPEC-001 |

### E2 — Search & Filter
| ID | User story | SP | Status | Spec |
|---|---|---|---|---|
| US-2.1 | As a driver, I want to filter lots by vehicle type (motorbike / car) | 3 | New | — |
| US-2.2 | As a driver, I want a list of lots sorted by distance | 5 | New | — |
| US-2.3 | As a driver, I want to filter by "open now" and price | 5 | New | — |

### E3 — Lot Details
| ID | User story | SP | Status | Spec |
|---|---|---|---|---|
| US-3.1 | As a driver, I want to see price, hours, photos and capacity of a lot | 5 | New | — |
| US-3.2 | As a driver, I want to tap "Navigate" to open Google/Apple Maps | 3 | New | — |

### E4 — Admin & Data
| ID | User story | SP | Status | Spec |
|---|---|---|---|---|
| US-4.1 | As an admin, I want to import existing Vũng Tàu parking data from OpenStreetMap | 3 | New | — |
| US-4.2 | As an admin, I want to add/edit/delete lots (via Supabase Studio) | 2 | New | — |
| US-4.3 | As an admin, I want to mark the "last verified" date of a lot | 2 | New | — |
| US-4.4 | As the team, we want to field-survey key areas (Bãi Sau, Bãi Trước, center…) | 5 | New | — |

### E5 — Platform
| ID | User story | SP | Status | Spec |
|---|---|---|---|---|
| US-5.1 | As a user, I want the app in Vietnamese and English | 3 | New | — |
| US-5.2 | As a user, I want to give location consent and read the privacy policy | 3 | New | — |

### E6 — Owner Portal
| ID | User story | SP | Status | Spec |
|---|---|---|---|---|
| US-6.1 | As an owner, I want to sign up (email/Google) and switch to owner mode | 3 | New | — |
| US-6.2 | As an owner, I want to claim an existing lot or register a new one | 5 | New | — |
| US-6.3 | As an owner, I want to upload verification documents and photos | 3 | New | — |
| US-6.4 | As an admin, I want to approve/reject owner claims | 3 | New | — |
| US-6.5 | As an owner, I want to edit my lot's price, hours and photos | 5 | New | — |
| US-6.6 | As an owner, I want to set live availability (available / almost full / full) with one tap | 3 | New | — |
| US-6.7 | As a driver, I want to see a "Verified" badge and the latest availability with its update time | 2 | New | — |

## Post-MVP (not prioritised yet)
| ID | Epic / idea | Notes |
|---|---|---|
| E7 | Monetization | Featured listing subscription first; VietQR transfer; needs business registration + e-invoice |
| E8 | Booking & payment | Commission model; MoMo/ZaloPay/VNPay |
| E9 | Reviews & user reports | "Lot is full", "price changed" |
| E10 | Dedicated admin web panel | Replace Supabase Studio |
| E11 | Store release | Google Play ($25) + App Store ($99/yr) |
| E12 | Multi-city expansion | Đà Lạt, Nha Trang, HCMC center |
