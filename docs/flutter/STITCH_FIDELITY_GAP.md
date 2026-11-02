# Stitch fidelity gap map

Scope: native Flutter presentation for Home, Explore, Reservation Create and Payment. Existing repositories, Riverpod providers, routes, authentication, request contracts and submit guards remain authoritative. Stitch HTMLs are visual references; sample content in them is not application data.

## Shared visual language

| Stitch element | Current Flutter | Structural gap | Planned treatment |
|---|---|---|---|
| 64dp branded header with clear title/actions | Material AppBar and title/actions | Header is functional but generic and has little branded hierarchy | Keep native AppBar, improve title/action sizing and whitespace without changing route behavior |
| Inter typography, compact labels, generous section spacing, rounded surfaces | Material 3 theme with green palette, rounded cards/buttons | Theme is close in color but cards and typography are mostly default Material compositions | Tune shared theme tokens and compose screen-specific cards; keep accessible contrast |
| Four-item bottom navigation with mint selected pill | Material NavigationBar in a rounded shell | Similar destinations, but selected treatment, height and inset differ | Keep labels/routes; tune icon size, indicator and shell spacing |

## Screen-by-screen map

### Home (`A2_home_dashboard.html` → `CustomerDashboardScreen`)

| Stitch element | Current widget/data | Gap | Change |
|---|---|---|---|
| Greeting and user identity under compact branded header | Greeting + name; notification and profile actions in AppBar | Identity is separated from the overview and hierarchy is flat | Group greeting/name with a concise dashboard introduction |
| Large dark active-storage hero | Four-metric summary card; active contracts are later list cards | No single hero role; HTML's smart-lock/telemetry/QR data is fictional/unsupported | Promote API summary into an overview card; show active contract summary only from API, otherwise a useful empty state |
| Pending payment card | API-backed pending reservations section | Generic list lacks a strong priority card | Emphasize actual pending item(s); preserve payment route and backend status |
| Four compact quick actions | Four API/app-route actions in a responsive Wrap | Current actions are separate Material cards | Compact icon tiles, retain the exact existing routes |
| Recent activity | API-backed recent stock movements and explicit empty/error states | Plain list styling | Use concise timeline-like cards using movement fields only |
| Featured facility image card | API facilities with actual first image/name/city/address | Flat card, no hierarchy | Larger image crop/overlay with only API-provided name/location; no distance, rating, price or promotion claims |

### Explore (`A3_explore.html` → `ExploreScreen`)

| Stitch element | Current widget/data | Gap | Change |
|---|---|---|---|
| Search-first header and clear action | Debounced search field with repository search | Search is below introductory copy and card stack is generic | Promote search in the first viewport; retain debounce, clear and repository behavior |
| Horizontally scrollable quick filters | No filters | No validated filter contract | Use only distinct cities derived from returned facility records, if the current API model provides them; otherwise omit filters |
| Result count and map action | Facility list | No count/map; map/location capability is not present | Show result count; omit map action because no map contract exists |
| Image-led facility cards with details and CTA | API image/name/city/address/status and navigation | Image has separate small content block; card hierarchy differs | Larger rounded image area, restrained API-backed availability badge, clear facility detail CTA |
| Trust/promotion banner | No such API-backed content | HTML makes unsupported insurance/guarantee claims | Omit |

### Reservation Create (`A4_reservation_create.html` → `ReservationCreateScreen`)

| Stitch element | Current widget/data | Gap | Change |
|---|---|---|---|
| Four-step progress line | No visible process line | Current form is one continuous page | Add a visual progress header reflecting facility → unit/time → duration → review; no navigation/business-state rewrite |
| Facility summary | API-backed facility image/name/address | Present but basic | Improve hierarchy and compactness |
| Selectable physical unit cards | Validated API units in a dropdown | Dropdown hides actual capacity/status information and selection | Present returned selectable units as cards, retaining the same selected physical unit ID and availability checks |
| Date selection and available slot cards | Real date picker + API time slots | Chips and sections lack Stitch hierarchy | Group date and slots into clear cards; keep real API slots only and explicit loading/error/empty states |
| Duration and review summary | Duration input and current selection | Summary/presentation weak | Add a compact data-derived review; do not invent prices/taxes/insurance |
| Terms checkbox and pinned CTA | Explicit unchecked terms consent, CTA at form end | CTA may scroll out of view | Pin CTA above app shell in safe-area-aware footer; retain all current guards and unchecked default |
| 15-minute inventory hold | No confirmed such API guarantee | HTML-only demo claim | Omit |

### Payment (`A6_payment_vietqr.html` → `PaymentScreen`)

| Stitch element | Current widget/data | Gap | Change |
|---|---|---|---|
| Amount/status hero | Backend payment amount/status in green card | Useful but overly dense and no visual grouping | Separate status and amount hierarchy with API values only |
| Server-generated QR card | Backend `qrUrl`, when supplied | QR is rendered but basic | Frame QR in a clean surface with bounded loading/error state; never substitute a demo QR |
| Transfer details and payment reference | Backend `bankInfo`, `paymentCode`, `referenceCode`, `expiresAt` | Plain information lines, no copy affordance | Group details, add copy only for nonempty server-provided values, maintain privacy |
| Pinned status-check CTA | Existing status-check button in scroll content | Can move out of view | Use a sticky footer for the existing check action; preserve polling/status rules |
| Countdown and payment guarantee copy | HTML-only hard-coded timer and claims | Not backed by response contract | Omit; display expiry only when backend supplies it |

## Data and safety decisions

- Home: exclude HTML sample customer name, verified badge, temperature/humidity, smart lock, QR unlock, incident controls, fabricated activity, and fake pending reservation. Use current API providers or their existing loading/error/empty states.
- Explore: exclude demo facilities, distances, availability counts not returned by API, prices, discount/rating claims, and unsupported service/insurance promises. A real image may be shown only when supplied by the facility API.
- Reservation: exclude fixed demo date/unit/slot/price, insurance/VAT assumptions, temporary lock/countdown, and any generated time slots. Keep terms acceptance unchecked and existing validation intact.
- Payment: exclude SVG/demo QR, static bank/account/amount/reference, fake countdown, delayed fake status, and payment guarantees. `PaymentScreen.initState` creates a payment session via POST; visual verification must use an isolated widget test fixture, never the production route.
- Facility detail and the remaining app are out of this fidelity pass; existing behavior remains as-is.

## Baseline evidence

Pre-change device captures from the existing authenticated session are under `docs/flutter/screenshots/`, including Home, Explore, Facility Detail, Reservation Create and My Bookings. Payment has no safe production-device capture because opening its route initiates a payment-session POST. The required implementation report will record which references/screens were actually rendered and verified.
