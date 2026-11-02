# Stitch -> Flutter Customer handoff (4 pages)

The four `.html` files were extracted unchanged from the user's combined Stitch HTML paste (only split into standalone documents). They are **visual references, not runtime implementation or API fixtures**.

- `A2_home_dashboard.html` — Home `/home`
- `A3_explore.html` — Explore `/explore`
- `A4_reservation_create.html` — Reservation Create `/reservations/create`
- `A6_payment_vietqr.html` — Payment `/payments/:id`
- `CODEX_IMPLEMENTATION_PROMPT.md` — Safe task specification for implementing these designs as **native Flutter widgets**.

## Notable mismatches to remove when porting

1. Payment HTML has a hand-drawn fake SVG QR, hard-coded bank account and a local demo timer/check-state JS. Use only backend QR/status/expiry.
2. Booking HTML hard-codes a May 2025 date, physical units, slots, capacity, pricing, insurance claims and an initial 'locked 15 min' message. Use separate availability API queries and existing submit validation.
3. Explore HTML uses fictional facilities, distances, discounts, services and insurance guarantees. Render real facility API results only.
4. Home HTML includes unsupported smart-lock/door QR/Bluetooth access, sample customer, storage data, transactions and activity. Do not ship those as actual customer actions.
5. Keep four-tab navigation and original app shell intact.

Open each HTML file in a browser for layout reference, not as an implementation target. Copy the whole handoff folder into the workspace (e.g. `design_refs/stitch_customer_2026-10-30/`) for Codex to read.
