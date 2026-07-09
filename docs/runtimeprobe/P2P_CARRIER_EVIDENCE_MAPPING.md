# P2P Carrier Evidence Mapping

This is a planning specification for future read-only P2P carrier discovery evidence. It is not an implementation, does not claim evidence rows exist today, and does not authorize RuntimeProbe writes, mutating RPCs, synthetic payloads, write-smoke tests, or CrabSyncV2 code.

## 1. Purpose

This document defines how future read-only RuntimeProbe carrier-discovery rows should become planning/status records in:

- [P2P Carrier Candidates](P2P_CARRIER_CANDIDATES.md).
- [P2P Carrier Visibility Matrix](P2P_CARRIER_VISIBILITY_MATRIX.md).
- [P2P Carrier Unsafe Paths](P2P_CARRIER_UNSAFE_PATHS.md).
- [P2P Carrier Write-Smoke Plan](P2P_CARRIER_WRITE_SMOKE_PLAN.md).

Future rows should be produced only by phases that satisfy [P2P Carrier Discovery Phase Contracts](P2P_CARRIER_DISCOVERY_PHASE_CONTRACTS.md) and [P2P Carrier Safety Gates](P2P_CARRIER_SAFETY_GATES.md).

Mapping evidence into a candidate/status doc does not approve a carrier. Read evidence never equals write evidence. A path can be visible, useful for P2P derivation, and still forbidden for `CrabSyncBlock` payload transport.

[P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md) defines readiness levels and decision outcomes after evidence rows are mapped.

## 2. Source Evidence Row Families

These future evidence kinds are planned names only. They are not currently implemented and this document does not require local UE4SS runtime.

### `P2PCarrier.Discovery.Candidate`

Purpose: records a scoped, read-only candidate field/event/function discovered for review.

Expected fields:

- `sessionId`
- `timestamp`
- `phaseId`
- `localRole`
- `context`
- `objectClass`
- `objectFullName` or redacted object identity
- `fieldOrEventName`
- `valueKind`
- `ownerSource`
- `visibilityDirection`
- `rawPrivateValuesEmitted`
- `gameplayAuthorityClass`
- `identitySensitivity`
- `savePersistenceSensitivity`
- `lifecycleState`
- `observedCadence`
- `observedCapacity`
- `result`
- `rejectionReason`
- `safetyMarkers`
- `notes`

### `P2PCarrier.Visibility.Sample`

Purpose: records a read-only visibility observation for a candidate in one role/context/direction.

Expected fields: `sessionId`, `timestamp`, `phaseId`, `localRole`, `context`, `objectClass`, redacted object identity, `fieldOrEventName`, `valueKind`, `ownerSource`, `visibilityDirection`, `rawPrivateValuesEmitted`, `lifecycleState`, `observedCadence`, `result`, `safetyMarkers`, and `notes`.

### `P2PCarrier.Capacity.Observation`

Purpose: records natural, read-only capacity/cadence observations after a candidate is already safe to read.

Expected fields: `sessionId`, `timestamp`, `phaseId`, `localRole`, `context`, `objectClass`, redacted object identity, `fieldOrEventName`, `valueKind`, `ownerSource`, `observedCadence`, `observedCapacity`, `rawPrivateValuesEmitted`, `result`, `safetyMarkers`, and `notes`.

### `P2PCarrier.Lifecycle.Sample`

Purpose: records read-only candidate behavior during join, travel, respawn, disconnect, reconnect, and role transitions.

Expected fields: `sessionId`, `timestamp`, `phaseId`, `localRole`, `context`, `objectClass`, redacted object identity, `fieldOrEventName`, `ownerSource`, `visibilityDirection`, `lifecycleState`, `result`, `safetyMarkers`, and `notes`.

### `P2PCarrier.Rejection`

Purpose: records why a path is rejected as a custom carrier.

Expected fields: `sessionId`, `timestamp`, `phaseId`, `localRole`, `context`, `objectClass`, redacted object identity, `fieldOrEventName`, `ownerSource`, `gameplayAuthorityClass`, `identitySensitivity`, `savePersistenceSensitivity`, `result`, `rejectionReason`, `safetyMarkers`, and `notes`.

### `P2PCarrier.Safety.Marker`

Purpose: records phase-level safety gates and privacy markers.

Expected fields: `sessionId`, `timestamp`, `phaseId`, `localRole`, `context`, `result`, `rawPrivateValuesEmitted`, `safetyMarkers`, and `notes`.

## 3. Mapping To `docs/P2P_CARRIER_CANDIDATES.md`

Candidate rows are created or updated only from read-only evidence rows. A candidate row is still not approval to use the path as a carrier.

Mapping rules:

- Candidate ID generation: `carrier-<normalized-object-class>-<normalized-field-or-event>`, with a numeric suffix if needed to avoid collisions.
- Object/Class normalization: use `objectClass`; avoid raw full names unless already redacted or safe.
- Field/Event/Function naming: use `fieldOrEventName` exactly enough to identify the surface, with private values omitted.
- Value kind mapping: copy `valueKind` when known, otherwise `unknown`.
- Owner/source mapping: copy `ownerSource`; unresolved ownership stays `unknown ownership`.
- Expected direction mapping: derive from `visibilityDirection`, preserving `unknown` when direction is inconclusive.
- Gameplay-authoritative classification: derive from `gameplayAuthorityClass`; gameplay-critical classes force rejection.
- Identity-sensitive classification: derive from `identitySensitivity`; raw/private identity defaults to rejected.
- Save/persistence-sensitive classification: derive from `savePersistenceSensitivity`; persistent save risk defaults to rejected pending review.
- Observed capacity/cadence fields: populate only from `P2PCarrier.Capacity.Observation` rows based on natural values.
- Lifecycle notes: summarize `P2PCarrier.Lifecycle.Sample` rows and stale/reset behavior.
- Evidence session reference: record `sessionId` and phase context.
- Next evidence needed: name the next read-only phase or human review needed.

Status transition rules:

- `unreviewed` -> `objectdump-only`
- `objectdump-only` -> `read-discovered`
- `read-discovered` -> `visibility-confirmed`
- `visibility-confirmed` -> `capacity-observed`
- any status -> `rejected-gameplay-authoritative`
- any status -> `rejected-local-only`
- any status -> `rejected-identity-risk`
- any status -> `rejected-save-risk`
- any status -> `rejected-unstable`
- `capacity-observed` -> `write-smoke-candidate`, future only and only after human review

No automated mapping may promote a candidate to `write-smoke-candidate` without explicit review. Even `write-smoke-candidate` is not authorization to write.

## 4. Mapping To `docs/P2P_CARRIER_VISIBILITY_MATRIX.md`

Visibility rows are one row per candidate/context/direction observation.

Allowed visibility classifications:

- `host-to-client`
- `client-to-host`
- `client-to-client`
- `local-only`
- `host-only`
- `joined-client-only`
- `all-visible`
- `unknown`
- `stale/partial visibility`

Handling rules:

- Multiple players: record one row per distinct source/observer role pair when the candidate can be separated safely; otherwise aggregate as `unknown` with notes.
- Asymmetric visibility: preserve asymmetry instead of upgrading to `all-visible`.
- Role ambiguity: use `unknown` or explicit role ambiguity notes; do not infer host/client behavior from ambiguous context.
- Stale values: mark stale behavior and avoid status promotion until lifecycle behavior is understood.
- Join/travel/respawn samples: write separate lifecycle-context rows; do not merge them into stable-run visibility.
- Raw/private value redaction: if `rawPrivateValuesEmitted = true`, mark the row unsafe for normal docs import unless explicit raw identity approval exists.

Visibility is read-only proof only. It does not prove correct owner writes, clear/reset behavior, or production transport safety.

## 5. Mapping To `docs/P2P_CARRIER_UNSAFE_PATHS.md`

Rejection rules:

- `gameplay-authoritative` -> unsafe.
- `currency/progression` -> unsafe.
- `identity/matchmaking` -> unsafe.
- `save-persistent` -> unsafe unless explicitly reviewed.
- `health/gameplay critical` -> unsafe as custom carrier.
- `equipment authority` -> unsafe as custom carrier.
- `inventory authority` -> unsafe as custom carrier.
- `UI/user-visible deception risk` -> unsafe unless explicitly reviewed.
- `local-only` -> unusable as P2P carrier.
- `requires mutating RPC` -> unsafe for RuntimeProbe and not a read-only carrier.
- `unknown ownership` -> unresolved or unsafe pending review.

Clarifications:

- A path can be safe to read but unsafe as a custom carrier.
- A path can be useful for P2P derivation but still forbidden for `CrabSyncBlock` payload transport.
- Unsafe carrier status does not erase previously confirmed safe read evidence.

## 6. Mapping To `docs/P2P_CARRIER_WRITE_SMOKE_PLAN.md`

A write-smoke row may be proposed only when all of the following are documented:

- Candidate is `visibility-confirmed` or `capacity-observed`.
- Candidate is absent from unsafe paths.
- Lifecycle behavior is documented.
- Owner/source is documented.
- Capacity/cadence is documented.
- Clear/reset theory is documented.
- Explicit user approval is still required.
- CrabSyncV2-only sandbox is required.
- RuntimeProbe must not implement or run write-smoke.

The mapping may prefill a checklist proposal, but it must not mark the test approved or authorized.

## 7. Evidence Confidence Levels

- `objectdump-only`: static symbol/candidate only; no runtime carrier evidence.
- `read-observed`: scoped read-only runtime candidate observed.
- `visibility-observed`: candidate visibility observed in at least one role/context/direction.
- `capacity-observed`: natural value capacity/cadence observed without synthetic payloads.
- `lifecycle-observed`: join/travel/respawn/disconnect behavior observed.
- `rejected`: candidate is unsafe or unusable as a carrier.
- `unresolved`: evidence is incomplete, ambiguous, or insufficient.
- `experimental-write-candidate`: future only; human-reviewed candidate that may request explicit sandbox approval.

## 8. Safety Marker Requirements

Future carrier-discovery read phases must include safety markers:

- `noWrites = true`
- `noRpcs = true`
- `noHud = true` unless specifically approved as read-only UI observation
- `noDeepArrays = true` unless the phase explicitly says otherwise
- `noInventoryInfo = true`
- `noEnhancements = true`
- `rawIdentityEvidence = false` unless explicitly approved
- `noDataAssetMutation = true`
- `passiveOnly = true` where applicable

Missing or contradictory markers should prevent status promotion.

## 9. Example Placeholder Mappings

These are fictional non-evidence examples. They do not prove a carrier exists.

| Example | Input idea | Mapping result | Reason |
|---|---|---|---|
| Cosmetic status field | A fictional transient cosmetic status field is read-discovered with no identity/save/gameplay markers. | `read-discovered` candidate. | Safe-looking read-only discovery can enter candidates, but still needs visibility/capacity/lifecycle evidence. |
| Health scalar | A documented health scalar is visible remotely. | unsafe-as-carrier, useful-as-visible-state. | Health can inform deterministic P2P planning but must not carry payloads. |
| PlayerName-like field | A fictional name/display field emits identity-like data. | `rejected-identity-risk`. | Identity and user-visible naming fields are not payload channels. |
| Local-only UI field | A fictional UI-only status appears only on local client. | `rejected-local-only`. | Local-only visibility cannot support P2P carrier transport. |

## 10. Relationship To CrabSyncV2 Planning

This mapping supports future P2P carrier docs if carrier-discovery phases are implemented and run. It does not unblock CrabSyncV2 implementation by itself.

It does not solve inventory item sync unless future evidence proves a carrier safe and item read/apply gates are separately satisfied.

Future docs/import tooling should use this mapping only after read-only carrier-discovery phases exist. Until then, carrier candidate, visibility, unsafe-path, and write-smoke docs remain templates/status docs rather than proof.
