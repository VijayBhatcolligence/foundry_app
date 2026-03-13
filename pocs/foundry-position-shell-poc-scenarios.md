# Foundry Position Shell PoC — Scenario Catalog

**Status:** Draft rewrite support document

## Purpose

This document captures the scenario inventory and success-threshold summary for
the Foundry Position Shell PoC.

It is the repo-local scenario catalog referenced by:

- `docs/pocs/foundry-position-shell-parity-evaluation.md`

This file exists so PoC execution depends only on repo-local documentation.

## 1. Position Module: Warehouse Clerk

**Simulated workflow:** Receive goods against a purchase order, scan item
barcodes, confirm quantities, flag discrepancies, and complete the receiving
transaction.

| ID | Scenario | What It Proves | Success Criteria |
|---|---|---|---|
| `W-1` | Continuous barcode scanning | Camera API streaming mode via native bridge; scan result injection into React form field | Scan-to-field latency `< 500ms`; continuous scan mode with no per-item button tap; haptic feedback on successful scan |
| `W-2` | Bluetooth scanner integration | Native Bluetooth HID/SPP pairing; scan events forwarded to React module via bridge | Scan from Zebra/Honeywell handheld scanner populates the active field in the React module; works when app is in foreground |
| `W-3` | Full offline receiving transaction | Local persistence; transaction queue; sync on reconnect | Complete a `50-line` receiving transaction with zero connectivity; all data persisted locally; sync executes automatically on reconnect with no data loss |
| `W-4` | Offline-first launch | App and position module available without network | Device in airplane mode, app opens, module loads from cache, previous data visible, new transactions queue locally |
| `W-5` | Asset/page caching | Shell caches position module bundles and static assets locally | Second load of position module `< 200ms` from local cache; no network request for cached assets; cache survives app restart |

## 2. Position Module: Quality Inspector

**Simulated workflow:** Perform an inspection against a checklist, capture
defect photos with annotations, attach them to checklist items, record
measurements, and sign off or raise an NCR.

| ID | Scenario | What It Proves | Success Criteria |
|---|---|---|---|
| `Q-1` | Photo capture with annotation | Native camera API; annotation overlay; EXIF metadata embedding | Camera opens in `< 300ms`; manual exposure/focus control available; annotation drawn on image; GPS and timestamp embedded |
| `Q-2` | Structured photo-to-form binding | Camera opens in context of a specific checklist item; photo auto-attaches to that item | Tapping `Add photo` on line item 3 opens camera, saves photo bound to line 3, and shows it as evidence on that line |
| `Q-3` | Document scanning | Native document detection, auto-crop, perspective correction | Point camera at a supplier certificate, auto-detect edges, crop and correct perspective, save as clean PDF-quality image |
| `Q-4` | Biometric sign-off | Step-up biometric re-authentication mid-session for consequential actions | Completing checklist and tapping `Sign Off` triggers Face ID / fingerprint prompt and records sign-off with biometric attestation |
| `Q-5` | Offline NCR with photos | Complete NCR with multiple attached photos while offline | Create NCR with `5` annotated photos, text notes, and severity classification offline; sync on reconnect with no photo loss |
| `Q-6` | Speech-to-text for notes | Native speech recognition for hands-free input | Dictated notes appear in the field with acceptable accuracy in a noisy environment |

## 3. Position Module: Production Supervisor

**Simulated workflow:** Monitor shift production targets, receive and act on
alerts, approve quality holds and overtime requests, and review shift handover
notes.

| ID | Scenario | What It Proves | Success Criteria |
|---|---|---|---|
| `P-1` | Rich push notifications with inline actions | Native push with action buttons; action result forwarded to React module | `Machine 7 DOWN` notification arrives; supervisor taps `Acknowledge` without opening app; acknowledgment recorded in backend |
| `P-2` | Background data refresh for dashboard | Background refresh; data current when app is foregrounded | Opening the app after `30` minutes shows dashboard data updated within the last `5` minutes |
| `P-3` | Biometric-gated approval | Step-up biometric auth for approval actions within session | Approving an overtime request triggers biometric prompt and records approval with identity attestation |
| `P-4` | Multi-role switching with security boundary | Position switch enforces fresh position-scoped session, not just module swap | Switching positions unmounts the current module, clears in-memory state, issues a fresh scoped session, mounts the new module in `< 1s`, and invalidates prior position access |

## 4. Cross-Cutting Scenarios

These scenarios validate architecture-level concerns independent of a specific
position module.

| ID | Scenario | What It Proves | Success Criteria |
|---|---|---|---|
| `X-1` | Auth flow end-to-end (mock) | System browser login, shell token receipt, session broker, bootstrap code, position-scoped web session | Mock flow enforces distinct scoped sessions per position; module cannot access data outside position scope; shell token never leaks to web layer |
| `X-2` | Module version update without app store release | Position module updated server-side; shell picks up new version | Updated module is detected, downloaded, cached, and loaded without native shell update |
| `X-3` | Graceful degradation on bridge failure | Error boundary in runtime host handles bridge unavailability | Simulated bridge failure produces graceful fallback, not crash or white screen |
| `X-4` | Module isolation | One position module cannot access another's data or state | Warehouse data is inaccessible to Quality module; switching positions clears previous in-memory state |
| `X-5` | Performance under load | React module rendering complex data inside WebView at acceptable frame rate | `500-row` scrollable list renders and scrolls at `60fps` on a mid-range device |
| `X-6` | Screen capture prevention | Sensitive data screens block screenshots | Platform techniques prevent screenshot capture on screens marked sensitive by the module |
| `X-7` | NFC asset tag reading | Native NFC tag read forwarded to React module via bridge | Tapping the device on an NFC tag places the tag ID into the asset lookup field |
| `X-8` | Bluetooth label printing | Native Bluetooth connection to label printer; print command from React module | React module sends print payload through the bridge and the label prints on a paired Zebra printer |
| `X-9` | Module provenance and bridge gating | Only first-party, verified modules receive execution and bridge access | Unverified or tampered module fails verification, does not mount, does not receive bridge access, and produces a controlled fallback |
| `X-10` | Navigation containment and CSP enforcement | Runtime host cannot be navigated to arbitrary origins; injected content cannot reach bridge | Host blocks arbitrary navigation/popups; strict CSP and origin policy prevent untrusted content from reaching bridge APIs or tokens |
| `X-11` | Bad module update rollback | Failed or incompatible updates do not strand the user | Incompatible or tampered module is rejected; last-known-good module remains available from cache without reinstall |

## 5. Store and Policy Validation

These scenarios validate store-review viability for the shell + downloaded
module model.

| ID | Scenario | What It Proves | Success Criteria |
|---|---|---|---|
| `S-1` | TestFlight submission (iOS) | Apple review accepts a Flutter shell that dynamically loads first-party React modules via WebView with a constrained native bridge | App accepted into TestFlight without rejection tied to downloaded modules, WebView-hosted software, or native bridge exposure; if challenged, reviewer feedback captured verbatim |
| `S-2` | Play Store internal test track (Android) | Google Play review accepts the same architecture | App accepted into internal track without rejection tied to dynamically loaded content, WebView-hosted modules, or JavaScript/native bridge exposure; if challenged, remediation documented |

## 6. Exploratory Tier

These are informative, not pass/fail for the core architecture.

| ID | Scenario | Notes |
|---|---|---|
| `E-1` | Critical alerts override Do Not Disturb | Requires special Apple entitlement; unlikely for ERP; explore feasibility only |
| `E-2` | Home screen widget | Proves Flutter extension capability, not shell-host-module architecture |
| `E-3` | Live Activity (iOS) | Same category as widget support; platform extension, not core architecture proof |

## 7. Success Criteria Summary

| Category | Threshold |
|---|---|
| Scan-to-field latency | `< 500ms` for camera and Bluetooth scanner paths |
| Camera open time | `< 300ms` from tap |
| Module load from cache | `< 200ms` |
| Module switch (role change) | `< 1s`, including fresh position-scoped session issuance and prior-session invalidation |
| Offline transaction | `50-line` receiving transaction completes and syncs with zero data loss |
| Offline launch | App and module usable with no connectivity |
| Background data freshness | Dashboard data `< 5 minutes` old on foreground |
| Push action without app open | Notification action recorded in backend without opening app |
| Biometric step-up | Completes in `< 2s`; attestation recorded |
| Scroll performance | `60fps` on `500-row` list on a mid-range device |
| Module update | New version detected, downloaded, and loaded without native shell release |
| Trust boundary | Unverified/tampered module never mounts and never receives bridge access; last-known-good fallback works |
| Host containment | Arbitrary navigation blocked; CSP/origin policy prevents untrusted content from reaching bridge or tokens |
| App Store acceptance | TestFlight and Play internal track accepted without policy rejection tied to downloaded modules, WebView-hosted software, or native bridge exposure |
