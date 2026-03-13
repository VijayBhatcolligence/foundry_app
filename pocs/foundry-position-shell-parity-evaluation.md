# Foundry Position Shell PoC — Architecture Parity Evaluation

**Status:** Draft rewrite

## 1. Purpose

This document does **not** replace Foundry's upstream architecture documents.
Those documents remain the source of truth for Foundry's intended product
architecture, runtime boundaries, auth model, and release model.

This document has a narrower and different job:

- anchor the PoC in the upstream Foundry architecture
- define the architectural comparison explicitly
- stress test the mixed client architecture against a full-native benchmark
- identify any capability, security, policy, or operability gap early

The core question is:

> For ERP position-holder workflows, can Foundry's mixed client architecture
> deliver sufficient parity with a hypothetical 100% native Flutter app, while
> preserving Foundry's upstream boundaries and long-term compiler/runtime model?

If the answer is no, the PoC must surface that early and specifically.

## 2. Upstream Background

This PoC derives from the existing Foundry architecture and should be read
alongside these canonical sources in the repo:

- `docs/foundry-doctrine.md`
- `docs/foundry-product-architecture.md`
- `docs/foundry-technical-architecture.md`
- `docs/foundry-identity-auth-decision.md`
- `docs/foundry-position-runtime-harness.md`
- `shared/position-runtime-sdk/contracts/position-runtime-contract.md`

The upstream architecture already establishes the intended product direction:

- a single native Flutter shell distributed as the customer app
- dynamically delivered position apps that are generated as React-based web
  artifacts
- a thin runtime host inside the shell
- shell custody of authentication, secure token storage, org/position
  resolution, and session brokering
- generated apps receiving scoped runtime context and brokered web-session
  access, not shell-owned identity tokens
- shell lifecycle decoupled from generated position-app lifecycle

This PoC is not re-litigating those choices from first principles. It is
testing whether that mixed architecture can, in practice, deliver enough of the
capability envelope that a full-native app would offer.

## 3. Comparative Framing

### World A — Full-Native Benchmark

A hypothetical 100% native Flutter application for each position.

This is the upper-bound benchmark for client capability:

- direct access to native device capabilities
- no WebView bridge boundary
- native lifecycle and performance characteristics throughout
- offline and local-storage design under full native control

This world is not necessarily what Foundry will build. It is the benchmark that
the mixed architecture is being tested against.

### World B — Foundry Mixed Client Architecture

The intended Foundry architecture:

```text
Flutter shell
  -> thin web runtime host
    -> dynamically loaded React position module
```

The question is not whether World B is identical to World A. The question is
whether World B achieves acceptable parity for the ERP workflows that matter,
without introducing unacceptable technical or policy risks.

## 4. Fixed Assumptions Imported From Upstream Foundry

This PoC must preserve the following constraints unless an explicit upstream
architecture change is proposed separately:

1. The customer-facing distribution unit is a Flutter native shell.
2. Position apps are dynamically delivered web artifacts, not separate native
   app-store-distributed apps.
3. The shell owns auth, secure storage, org/position resolution, and app
   session brokering.
4. The web layer receives scoped session/context only; shell identity tokens
   do not leak to generated modules.
5. The shell does not render business UI.
6. The runtime host remains thin infrastructure, not a second product shell.
7. Position apps target a stable runtime contract rather than host internals.
8. Position-app delivery remains compatible with Foundry's long-term activation
   model, not a parallel ad hoc deployment model.

If the PoC appears to require violating any of these assumptions in order to
reach parity, that is a major finding.

## 4A. Baseline Architecture Under Test

The baseline client architecture being tested in this PoC is the Foundry
three-tier model:

```text
Flutter shell
  -> web runtime host
    -> dynamically loaded React position module
```

### Tier 1 — Flutter Shell

The shell is the native custody layer. It owns:

- native distribution
- secure auth/token custody
- org/position resolution
- app session brokering
- WebView lifecycle
- trusted bridge entrypoints
- native capability mediation

The shell does not own business UI.

### Tier 2 — Web Runtime Host

The web runtime host is a thin in-WebView runtime layer. It owns:

- bootstrap redemption into a scoped web session
- mount/unmount of the selected position module
- runtime mediation between shell and generated app
- compatibility checks, fallback handling, and host-side containment

The runtime host is infrastructure, not a second application shell.

### Tier 3 — React Position Module

The position module is the business application layer. In production it is
compiler output. In the PoC it may be hand-authored, but it must behave as if
it were compiler-target output:

- mounts through the defined runtime contract
- consumes scoped session/context only
- has no shell-token access
- does not depend on shell internals outside the contract

### Execution Rule

The PoC should begin by attempting to satisfy the demo scenarios using this
baseline architecture as-is.

The point of the PoC is to determine whether this baseline can achieve
acceptable parity with the full-native benchmark. It is not to drift into a new
architecture silently during implementation.

## 4B. Deviation Control and ADR Requirement

Implementation deviations are allowed only when the PoC produces evidence that
the baseline architecture is insufficient, materially suboptimal, or needlessly
complex for a required scenario.

If the team departs from the baseline architecture under test, that deviation
must be documented through an explicit ADR before it becomes part of the PoC's
recommended architecture.

### ADR Trigger Conditions

An ADR is required if implementation work proposes any of the following:

- changing the shell / runtime-host / module boundary
- expanding the bridge into a broader or different capability model
- changing the auth/session ownership model
- changing how modules are packaged, mounted, or versioned
- introducing a different host-orchestration model
- introducing a materially different offline or local-data model as a required
  architecture element
- introducing a different update or delivery mechanism than the baseline path

### ADR Minimum Content

Each deviation ADR must state:

1. the baseline assumption being changed
2. the PoC evidence that exposed the problem
3. the alternative approach being adopted
4. why the baseline approach is insufficient or inferior
5. impact on:
   - upstream Foundry architecture
   - runtime contract shape
   - auth and trust boundary
   - compiler target expectations
   - delivery, activation, and rollback model
6. whether the deviation is:
   - a local implementation choice
   - a PoC-only workaround
   - or a proposed upstream architecture change

### Decision Discipline

The default rule is:

- evidence may challenge the baseline
- evidence does not silently replace the baseline

That keeps the PoC as a controlled experiment rather than an accidental
architecture redesign.

## 5. What This PoC Is Actually Trying To Prove

The PoC exists to answer four questions.

### 5.1 Capability Parity

Can the mixed architecture expose the native and offline capabilities that ERP
users materially need, at acceptable quality, through the shell and bridge?

### 5.2 Boundary Integrity

Can it do so without collapsing the upstream trust boundary, auth/session model,
or shell thinness?

### 5.3 Operational Viability

Can it support dynamic module updates, compatibility checks, rollback, and
app-store distribution safely?

### 5.4 Long-Term Compilerability

Does the resulting runtime surface remain small, stable, and structured enough
for compiler-generated output to target realistically?

## 6. What This PoC Must Not Accidentally Become

This PoC is not:

- a replacement for upstream Foundry architecture
- a generic multi-app super-app platform design exercise
- a mandate that every nice-to-have native feature becomes a core runtime
  contract primitive
- a justification for leaking shell tokens or turning the bridge into a general
  business-logic proxy
- a decision to standardize on a specific offline-storage or sync design unless
  that design is proven necessary for parity

## 6A. Recommended PoC Execution Model

The recommended execution model is:

- one shared walking-skeleton baseline
- implemented in thin, risk-first slices
- with isolated spikes only for exceptional capability questions

This is preferred over both:

- a big-bang implementation proving every scenario at once
- fully separate implementations for each scenario

### Why This Model

- Big-bang delivery discovers architectural failure too late.
- Fully separate scenario implementations duplicate the hardest shared work:
  shell, session, trust boundary, delivery, and lifecycle.
- A shared baseline keeps the PoC honest to the architecture under test.
- Thin slices keep the PoC lightweight and fast.

### Baseline Execution Pattern

1. Build one minimal shared shell / runtime-host / module path.
2. Prove the cross-cutting architecture-critical concerns first.
3. Add one scenario slice at a time using the thinnest possible module.
4. Keep scenario implementations minimal and evidence-oriented.
5. Isolate unusual platform questions as spikes unless they force a baseline
   change.

## 6B. Suggested Scenario Sequencing

The PoC should be sequenced in the following order.

### Slice 1 — Foundation

Prove the minimum viable architecture path:

- shell launch
- mock login
- position resolution
- bootstrap to scoped web session
- runtime host boot
- one module mount/unmount
- role context passed correctly
- no shell-token leakage

### Slice 2 — Trust and Delivery

Prove the architecture is safe and updateable:

- version manifest
- module update without shell release
- compatibility check
- provenance and integrity verification
- CSP/origin/navigation containment
- last-known-good fallback

### Slice 3 — Offline-Critical Workflow

Use the thinnest Warehouse-style scenario to prove:

- offline launch
- local persistence
- one scan-driven transaction path
- reconnect and sync recovery
- cached relaunch

This should be the first business workflow slice because it stress-tests a
central claim of the mixed architecture.

### Slice 4 — High-Trust Workflow

Use the thinnest Supervisor-style scenario to prove:

- role switch invalidates prior scope
- module remount under fresh scoped session
- one consequential approval action
- biometric or step-up confirmation

### Slice 5 — Rich Device Workflow

Use the thinnest Quality-style scenario to prove:

- photo capture
- attachment to a specific workflow item
- offline durability of attachment data
- reconnect recovery

### Slice 6 — Peripheral Spikes

Run isolated spikes for capabilities that are useful but should not distort the
main baseline until proven necessary:

- Bluetooth scanner support
- Bluetooth printing
- NFC
- speech-to-text
- push action routing
- background refresh

### Slice 7 — Store and Policy Validation

This lane should start as early as practical once the shell can load a
downloaded first-party module with a constrained bridge.

Do not wait for every business scenario to finish before testing review risk.

## 6C. Implementation Discipline Rules

The PoC should optimize for speed, but speed must come from tight slices and
minimal scenario implementations, not from uncontrolled architectural drift.

### Rules

- Keep one shared baseline implementation for shell, runtime host, session, and
  trust boundary.
- Prove one scenario slice at a time.
- Build the thinnest possible workflow that proves the scenario.
- Do not build full apps when a minimal vertical path is sufficient.
- Prefer narrow typed capability additions over a generic bridge API.
- Generalize a capability only after repeated evidence shows it is shared.
- Treat scenario modules as lightweight evidence artifacts, not polished
  product surfaces.
- Use isolated spikes for unusual platform questions instead of polluting the
  shared baseline too early.
- Any meaningful baseline drift requires an ADR per the deviation rules above.

### Explicit Non-Goals For Execution

- no big-bang implementation
- no premature generalized bridge platform
- no hidden scenario-specific shortcuts that bypass the baseline boundary
- no silent replacement of the baseline architecture under test

## 6C.1 Repository and Branching Directive

The authoritative PoC implementation should be developed inside this Foundry
repo on:

- a dedicated PoC branch
- a separate worktree for that branch

This PoC is testing Foundry's architecture and should remain close to:

- upstream docs
- runtime contracts
- ADR history
- future promotion path into canonical implementation

### Sharp Rule

- The primary PoC must not be developed as an independent product codebase in a
  separate repository.
- If an external repository is used for a narrow platform spike, it is
  disposable evidence only, not the authoritative PoC.
- Any finding from an external spike must be pulled back into this repo through
  documentation and, where relevant, an ADR.

## 6D. PoC Module Authorship Role

The PoC should explicitly recognize a **Module Author** role for the hand-coded
React position modules.

This role exists because the modules are hand-authored stand-ins for future
compiler output. They must be fast to build, but still disciplined enough to be
meaningful as evidence.

### Role Responsibilities

- implement the thinnest React module needed to prove each scenario
- behave as a stand-in for plausible compiler output
- stay inside the runtime contract and approved boundary model
- avoid direct dependency on shell internals
- surface any pressure on the runtime contract, bridge, or session model
- raise ADR pressure when a scenario cannot be achieved cleanly within the
  baseline architecture

### Freedom Model

Module authors have:

- high freedom inside the module
- low freedom at the architecture boundary

They are free to choose:

- internal UI composition
- local state structure
- minimal workflow implementation details
- disposable scenario-specific code inside the module

They are not free to change without ADR:

- auth/session ownership
- mount/unmount contract
- shell-token access rules
- host/module boundary shape
- bridge entrypoint model
- packaging, delivery, or compatibility assumptions

### Desired Expertise

The Module Author should be strong in:

- React and TypeScript implementation
- rapid scenario prototyping
- working within strict host/runtime boundaries
- translating business scenarios into minimal executable workflows

The Module Author is not acting as an exception to the future compiler target.
The authored module should be treated as a structured stand-in for what the
compiler could realistically be expected to emit later.

## 7. Evaluation Model

Each scenario in this PoC must be classified into one of three buckets.

### 7.1 Must-Match Full-Native Capability

If World B cannot satisfy these adequately, the mixed architecture has failed
the PoC for Foundry's purposes.

- secure auth and session handling with no shell-token leakage to the module
- dynamic position-module delivery without native shell release
- module provenance, integrity verification, and controlled rollback
- position-scoped isolation during role switching
- at least one real offline-critical workflow with durable local persistence and
  successful recovery/sync
- at least one scan/camera-heavy workflow
- at least one consequential approval flow requiring step-up auth or biometrics
- acceptable module performance, mount time, and recovery behavior
- app-store policy viability for the shell + downloaded-module pattern

### 7.2 Acceptable Degradation Relative To Full Native

World B does not have to be literally identical to World A. Some degradation is
acceptable if it stays within explicit thresholds and does not change the
business outcome.

Examples:

- slower cold start than a pure native screen, but still within an acceptable
  threshold
- slightly higher bridge latency than direct native invocation, but still fast
  enough for the workflow
- a narrower set of advanced native integrations in early phases, provided the
  essential ERP workflows are still supported

### 7.3 Exploratory Only

Useful to investigate, but not architecture pass/fail on their own.

Examples:

- home screen widgets
- lock-screen live activities
- critical alerts requiring special entitlements

## 7A. Quantitative Parity Thresholds and Baseline Measurements

The following quantitative thresholds are imported from the repo-local scenario
catalog and should be used to keep `acceptable quality` and `acceptable
degradation` objective.

### Core Thresholds

| Metric | Target |
|---|---|
| Scan-to-field latency | `< 500ms` |
| Camera open time from tap | `< 300ms` |
| Cached module load | `< 200ms` |
| Position / role switch including fresh scoped session issuance | `< 1s` |
| Scroll performance | `60fps` on a `500-row` list on a mid-range reference device |
| Offline transaction durability | zero data loss for the tested offline-critical workflow |

### Mandatory Baseline Measurements

The following must be measured and reported even if no universal threshold is
set up front:

| Measurement | Why It Matters |
|---|---|
| Raw bridge round-trip latency under idle conditions | Isolates the intrinsic bridge tax independent of any specific capability |
| Raw bridge round-trip latency under concurrent load | Predicts viability for high-frequency and overlapping interactions |
| WebView engine cold-start time on a low-end Android reference device | Captures the largest client-side penalty of World B relative to World A |
| Steady-state memory footprint of shell + WebView + runtime | Informs device support floor and memory-management strategy |
| Comparative memory footprint against a minimal pure-Flutter reference where feasible | Quantifies the actual tax of the mixed architecture |

These baseline measurements must feed into the parity matrix and the final go /
conditional-go / no-go recommendation.

## 8. Architecture Fail Conditions

The mixed architecture should be considered a failure for Foundry if the PoC
reveals any of the following:

1. A must-have ERP capability cannot be exposed reliably through the shell and
   bridge.
2. The capability only works by violating Foundry's auth or trust boundary.
3. App-store review rejects the pattern in a way that materially constrains the
   architecture.
4. The bridge surface expands into an unbounded generic RPC layer that is too
   broad or unstable for compiler-generated clients to target safely.
5. Module, host, and shell version compatibility becomes too fragile to manage
   operationally.
6. WebView lifecycle, memory behavior, or performance is too unstable for
   realistic daily use.
7. The resulting runtime shape is too host-coupled, too imperative, or too
   stateful for the compiler to target cleanly.
8. Dynamic update, rollback, and last-known-good recovery cannot be made
   dependable.

## 9. Scenario Categories

This document is the evaluation framework that wraps the repo-local scenario
catalog in
`docs/pocs/foundry-position-shell-poc-scenarios.md`: Warehouse Clerk, Quality
Inspector, Production Supervisor, Cross-Cutting, Store / Policy Validation, and
Exploratory scenarios.

The scenario catalog should be interpreted through
the parity model above rather than as a broad feature showcase.

Before implementation begins, execution planning should maintain an explicit
mapping from active scenario IDs or scenario groups into this framework.

### 9.1 Security, Session, and Trust Boundary

These are core pass/fail scenarios.

- shell login through system browser
- org/position resolution
- bootstrap to position-scoped web session
- no shell-token leakage to the web layer
- module provenance and integrity verification
- bridge gating based on trust, compatibility, and scope
- role switching with explicit session invalidation and remount
- host containment: CSP, origin control, navigation blocking, no arbitrary
  bridge exposure

### 9.2 Runtime Lifecycle and Delivery

These are core pass/fail scenarios.

- cached module load
- module update without native shell release
- incompatibility rejection and last-known-good fallback
- mount/unmount behavior on role change
- version compatibility checks across shell, host, and module
- predictable failure handling instead of white screens

### 9.3 Offline and Local Durability

These are pass/fail for at least one offline-critical workflow.

- offline launch of shell and cached module
- local persistence of in-progress work
- recoverable sync after reconnect
- attachment durability for offline-created artifacts
- protection against data loss after app restart or intermittent connectivity

This category should prove parity on business outcome, not prematurely lock
Foundry into one permanent local-storage design.

**Ownership open question.** The PoC should explicitly test whether WebView-side
offline mechanisms such as service worker support, Cache API behavior, and
IndexedDB are viable in the embedded WebView context before treating
shell-mediated local persistence as a permanent architectural requirement.

- If embedded web offline mechanisms are unreliable or infeasible, that is
  evidence for shell-mediated offline support.
- If embedded web offline mechanisms are viable for a scenario, that is
  evidence that not all offline behavior needs to become a bridge-owned
  capability.

### 9.4 Native Capability Parity

These are used to test whether the bridge can provide the native affordances
that matter most.

- barcode scanning
- camera capture and photo attachment
- biometric step-up for consequential actions
- push notifications and action routing
- Bluetooth peripherals where relevant
- NFC where relevant
- speech-to-text if required by workflow

The purpose is not to prove every imaginable device feature. It is to find out
whether the bridge model can support the native interactions ERP work actually
needs.

### 9.5 Performance and Stability

These are parity and operability checks.

- scan-to-field responsiveness
- raw bridge round-trip latency under idle conditions
- raw bridge round-trip latency under concurrent load
- concurrent bridge contention behavior: serialization, parallelism, queuing,
  back-pressure, and failure mode under overlapping calls
- module mount/switch latency
- WebView engine cold-start time on a low-end Android reference device
- scroll/rendering under realistic list sizes
- steady-state memory footprint of shell + WebView + runtime
- comparative memory footprint against a minimal pure-Flutter reference where
  feasible
- memory pressure behavior during repeated module switches
- WebView recovery after unload/reload
- no progressive degradation over extended use

### 9.6 Store and Policy Viability

These remain mandatory.

- TestFlight acceptance
- Play internal-track acceptance
- reviewer response to downloaded first-party modules
- reviewer response to bridge-mediated native capabilities

## 10. Recommended Success Outputs

The PoC should produce a sharper set of outputs than the original version.

1. A **parity matrix** for each tested capability:
   `full-native benchmark`, `mixed-architecture result`, `threshold or
   measurement`, `degradation class`, `verdict`.
2. A **gap register** that classifies every gap as one of:
   `fundamental limitation`, `policy risk`, `implementation gap`, or
   `acceptable degradation`.
3. A **runtime-boundary report** describing whether the tested bridge shape is
   still small and stable enough for compiler-generated modules to target. This
   should include a bridge surface inventory: entrypoint count, usage by
   scenario, and any imperative or stateful patterns required.
4. A **store-review finding** with hard evidence, not assumption.
5. A **go / conditional-go / no-go recommendation** for the mixed
   architecture.

## 11. Recommended Scope Adjustments

To keep the PoC decisive, the evaluation should be re-weighted.

### Must Emphasize

- auth/session boundary integrity
- dynamic module loading and safe rollback
- trust boundary and provenance enforcement
- offline-critical transaction durability
- at least one camera/scan-heavy workflow
- at least one biometric or high-trust action
- module lifecycle and performance under realistic usage
- app-store acceptance

### Keep, But As Supporting Evidence

- Bluetooth scanner and printer support
- NFC support
- speech-to-text
- background refresh

### Keep Exploratory

- critical alerts
- live activities
- home screen widgets

## 12. Non-Goals for This PoC

The PoC should avoid claiming decisions on these unless a failure forces the
issue:

- the final permanent bridge API shape
- the final permanent local database abstraction
- the final permanent offline sync architecture
- the final compiler output packaging format
- the final full runtime contract evolution path

The PoC may inform these. It should not silently settle them.

## 13. Revised Verdict Logic

The PoC succeeds only if all of the following are true:

1. The mixed architecture supports the must-match scenarios at acceptable
   quality.
2. It does so without violating the upstream Foundry shell/runtime/auth
   boundaries.
3. It remains app-store viable.
4. The bridge and runtime shape remain sufficiently disciplined for long-term
   compiler targeting.
5. Any remaining gaps are classified as acceptable degradation or tractable
   implementation work, not fundamental architectural blockers.

The PoC fails if the architecture reaches feature parity only by becoming a
generic native RPC platform, breaking the auth boundary, or creating an overly
fragile runtime that compiler-generated position apps cannot safely target.

## 14. Practical Interpretation

The right mental model for this PoC is:

- upstream Foundry defines the intended shell/runtime architecture
- a full-native app defines the capability benchmark
- this PoC is the falsification harness for the mixed architecture

It should answer:

- where the mixed architecture reaches effective parity
- where it has acceptable degradation
- where it has hard limits
- whether those hard limits are acceptable for Foundry's ERP product

That is the decision this PoC should be optimized to make.
