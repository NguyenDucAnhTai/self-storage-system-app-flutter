# Flutter Developer 2 — Backend and Frontend Analysis

> Superseded by the full implementation status in [docs/flutter](../flutter/ARCHITECTURE.md). The feature tree described below has since been integrated into the app shell, auth, navigation, Explore and customer screens.

## Project structure

- FE workspace: `apps/web` (Next.js), `apps/flutter_mobile` (standalone Flutter), `packages/shared` (TypeScript web contracts).
- BE workspace: `C:/Users/laptop/Downloads/self-storage-system-be-dev`, Express/TypeScript with tsoa controllers, Zod request/response schemas, service/repository/model modules, MongoDB/Mongoose, and shared response envelopes.
- Flutter consists of generated Android/iOS shells, `lib/main.dart`, locale/image assets, and starter dependencies. No existing `lib/app`, `lib/core`, auth, explore, reservation, or payment source modules were present.

## Backend architecture and contract source

Reservation and payment use controller → service → repository/model layers. Controllers return `{success,statusCode,messageCode,message,data}`. Zod middleware validates input; service response validation shapes DTOs. Relevant evidence is in the BE `src/modules/{reservation,payment,facilityTimeSlot,storageUnit,auth}` trees. The FE web's reservation management API is useful for corroboration but is manager-facing and not the customer contract authority.

## Current frontend and Flutter readiness

The Flutter app is a bare `StorageHub` starter. Dependencies already include Riverpod, Dio, GoRouter, secure storage and intl, but none is wired into the starter. The web app has Axios cookie refresh handling and business-operation screens; no shared Flutter API client/auth/token provider exists. Existing bilingual locale files include reservation/payment labels, but no customer reservation or payment implementation exists. Mobile migration and missing core flows are also stated in root README.

## Reservation business flow (verified)

Customer submits facility, physical `storageUnitId`, `checkInDate`, `checkInTimeSlot`, rental duration, offering ID, optional start date/amenities/notes. BE validates active facility/unit compatibility, open time slot/date/capacity and date rules, reserves the physical unit, creates a `PENDING_PAYMENT` hold and expiration. Customer reads list/detail, requests payment, then BE SePay webhook updates payment/reservation. Facility staff later confirms. Customer cancellation has a required reason and BE refund policy. The customer create/list/detail/cancel endpoints exist. There is no reservation-specific availability route; physical units are fetched via `/storage-units/facility/{facilityId}/available`, and check-in slots via `/facility-time-slots/facility/{facilityId}/available?date=...`.

## Payment business flow (verified)

`POST /payments` with `purpose: reservation_deposit` and reservation ID creates/reuses an active payment. The response provides a server-generated SePay VietQR URL, bank info, amount, payment code, expiry and status. Mobile polls `GET /payments/{id}`; only `status=paid` is authoritative. BE webhook verifies SePay API key and performs payment state changes. Valid statuses are pending, partially_paid, paid, expired, cancelled. BE has no distinct failed status; expired/cancelled sessions can be retried if reservation remains eligible.

## Authentication dependencies

BE auth supports login/register/refresh and returns access/refresh token pair in `data` (with auth cookies also set). Web uses HttpOnly cookies and Axios refresh. No Flutter token storage or shared Dio interceptor exists. Reservation/payment controllers have fallback caller extraction from `req.user`, `x-user-id`, bearer token or access cookie; authorization decorators are commented and role checks marked TODO. Feature integration must provide an authenticated shared Dio client and backend authorization must be resolved before customer data is safely exposed.

## Reuse and new work

Reusable: existing Dio/Riverpod/GoRouter dependencies, locale strings, web API endpoint references (corroborative), BE DTO/schema contracts. New: Dart models/repositories/screens/payment tracker and integration facade in `lib/features/reservations` and `lib/features/payments`. Developer 1 owns app/core/auth/explore, so no files in those paths or `main.dart` are changed.

## Current implementation scope

Feature repository supports availability, available physical units, reservation create/list/detail/cancel, payment session creation and payment detail retrieval. Reusable screens cover reservation list/detail/cancel and server QR display/status. There is no booking form because facility/unit navigation state and Developer 1's explore integration contract are not available yet.
