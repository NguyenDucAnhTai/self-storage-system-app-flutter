# Backend Handoff: Incident Evidence Upload Contract

**Date:** 2026-11-01  
**Scope:** Static review of the local Backend source and Flutter's incident-create gate. No Backend source was changed and no API request or upload was made.

## Current block

Flutter keeps incident creation blocked in `IncidentCreateBlockedScreen`. The Backend incident request requires `images` to contain at least one valid URL, but Flutter has no approved image-picker-to-upload flow. A URL alone does not prove who uploaded an asset or which incident/facility it belongs to.

The Backend handoff must define the upload and evidence-validation contract before Flutter enables incident creation. Do not use a hardcoded evidence URL or accept an arbitrary URL supplied by the client.

## Findings from source

- `src/modules/upload/upload.controller.ts` exposes `POST /upload/signature`. Its bearer/cookie `@Security` declarations are commented out. Its current `extractCaller` accepts a caller-supplied `x-user-id` and `x-user-role` fallback before checking a verified bearer token or cookie. The role TODO lists `CUSTOMER`, `FACILITY_STAFF`, `FACILITY_MANAGER`, `BUSINESS_OPS_MANAGER`, and `SYSTEM_ADMIN`, but the endpoint does not enforce that list or any role.
- `src/modules/upload/schemas/upload.request.schema.ts` accepts an optional `folder`; it checks only non-empty text and the characters allowed by `^[\w\-/]+$`. It does not bind a folder to the authenticated user, facility, contract, or incident.
- `src/modules/upload/upload.service.ts` signs only `folder` and a Unix `timestamp`. It returns `signature`, `timestamp`, `apiKey`, `cloudName`, and `folder`. No allowed MIME list, extension, maximum bytes, image count, public ID, resource type, upload type, access mode, context, or ownership claim is included in the signed parameters.
- `src/modules/upload/schemas/upload.response.schema.ts` confirms only those five signature response fields. The Backend does not expose an upload-completion/asset-registration response contract to Flutter.
- `src/modules/incident/schemas/incident.request.schema.ts` requires `images` to be one or more syntactically valid URLs, with no maximum count or allowed-host rule. `src/modules/incident/incident.service.ts` stores the submitted strings in `images`; no Cloudinary asset ownership/metadata verification is evident in that path.
- `src/modules/incident/incident.controller.ts` also has commented bearer/cookie security decorators and a TODO listing Customer, Facility Staff, and Facility Manager roles. Its caller extraction has the same identity-header fallback. Do not enable the FE create action until the incident endpoint's auth and scope checks are accepted too.
- The current folder enum has `self-storage/general`, `self-storage/amenities`, `self-storage/facilities`, `self-storage/unit-types`, `self-storage/avatars`, `self-storage/contracts`, and `self-storage/skus`. There is no dedicated incident-evidence folder.

These are source findings only. Cloudinary account-level restrictions and deployment configuration were not available in the reviewed files, so no effective account limits or delivery privacy can be asserted.

## Decisions required from Backend

1. **Signature roles and identity:** Enable verified bearer/cookie authentication, remove identity-header authority, and define the minimum roles. State whether only an authenticated Customer may request Customer incident evidence signatures. Derive the reporter and permitted contract/facility scope from the verified principal and related records.
2. **Purpose-bound upload intent:** Replace arbitrary client-selected folders with a narrowly scoped incident-evidence intent. Bind each signature or upload intent to reporter, facility/contract (and incident draft if applicable), purpose, and an opaque server-generated upload ID. Define whether the signature can be replayed and its effective expiry; the current code contains no nonce or single-use tracking.
3. **Content policy:** Specify accepted MIME types and extensions (for example JPEG/PNG only if approved), maximum bytes per image, maximum image count, dimensions, animation policy, and whether HEIC/WebP are accepted. Enforce the policy in trusted upload/asset-registration code and Cloudinary account settings; a client-side picker filter is not enforcement.
4. **Cloudinary upload protocol:** Publish the exact HTTPS upload endpoint and `resource_type`/`type`, form field names, signed parameter set, and success/error responses. The current signature payload supplies `cloudName`, `apiKey`, `timestamp`, `signature`, and `folder`; it does not by itself upload a file or return `secure_url`/`public_id`. Define if Flutter uploads directly to Cloudinary or through a Backend proxy.
5. **Public/private delivery:** State whether incident evidence is public, authenticated, or private/authenticated. Define access control for previews and downloads, retention, deletion, and cache behavior. Do not assume the default delivery mode is appropriate for sensitive incident evidence.
6. **Completion registration and ownership:** Add a Backend completion/registration step that verifies the Cloudinary response from trusted provider metadata (asset/public ID, folder, bytes, format, resource type, upload timestamp, and any signed intent metadata). Store a server-side ownership record. On `POST /incidents`, accept registered asset IDs (preferred) or verify each URL belongs to the authenticated reporter and relevant facility/contract; arbitrary URL strings are insufficient.
7. **Incident validation:** Enforce Customer ownership of the contract/storage unit/facility, require evidence assets registered to that reporter and incident intent, reject cross-customer/replayed/expired/unregistered assets, cap image count, and ensure all assets are images satisfying policy.
8. **Rejected/orphaned assets:** Specify cleanup for abandoned uploads, failed incident submission, rejected assets, and deleted/cancelled incidents. Define TTLs and idempotent cleanup behavior.
9. **Flutter DTOs and lifecycle:** Publish typed DTOs for upload intent creation, Cloudinary upload response, Backend asset registration, and incident submission. Include stable IDs, safe display metadata, error codes, expiry, and retry/idempotency behavior. Confirm whether URLs are returned to Flutter at all.
10. **Security acceptance tests:** Add tests for unauthenticated and wrong-role requests, forged identity headers, cross-customer uploads, wrong facility/contract, invalid MIME/extension, oversized files, image-count limits, expired/replayed intents, arbitrary external URLs, Cloudinary asset mismatch, orphan cleanup, and incident submission with an unowned asset.

## Proposed safe sequence

1. Backend publishes and implements the authenticated, purpose-bound upload-intent and asset-registration contract.
2. Backend verifies asset ownership/content and secures incident create/list/detail routes.
3. Backend supplies an isolated nonproduction Cloudinary/test configuration and test accounts.
4. Flutter implements image selection, validation for usability, upload progress/retry, asset registration, evidence preview/removal, and incident submission against mocks first.
5. Enable live testing only after Backend security tests pass in the isolated environment; keep incident creation blocked until then.

## Current Flutter behavior

The incident create route renders an explicit blocked screen. Existing incident listing/detail operations are separate and were not changed by this task. No fake evidence, upload, incident, or production call was made.
