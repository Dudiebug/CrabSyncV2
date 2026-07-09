# CrabSyncV2 P2P Carrier Research Plan

This document is planning-only. It does not authorize implementation, RuntimeProbe writes, mutating RPC calls, synthetic payload injection, or local UE4SS runtime requirements.

## 1. Purpose

The purpose of this plan is to find whether Crab Champions has a safe replicated carrier that could eventually carry a small `CrabSyncBlock` between clients.

Carrier research is separate from inventory read proof. Inventory still requires its own evidence for item identity, `InventoryInfo`, `Enhancements`, duplicate semantics, remote visibility, and safe apply behavior.

RuntimeProbe can only perform read-only discovery and visibility watch work. Any write-smoke test belongs to a later CrabSyncV2-only sandbox, outside RuntimeProbe default behavior, after explicit approval.

A carrier is not assumed. It must be proven through evidence, and unsupported is an acceptable result.

Carrier readiness is subordinate to [CrabSyncV2 Readiness Checklist](CRABSYNCV2_READINESS_CHECKLIST.md). Future carrier phases should close with [Phase Handoff Template](PHASE_HANDOFF_TEMPLATE.md), including the carrier gate reached and the gates that remain separate.

## 2. Carrier Definition

A valid `CrabSyncBlock` carrier must be:

- Replicated to remote clients.
- Visible from host and joined-client perspectives.
- Non-gameplay-authoritative or safely ignored by the vanilla game.
- Writable or triggerable by the correct owner later, after separate sandbox proof.
- Not saved permanently in a harmful way.
- Capacity-known.
- Cadence-known.
- Lifecycle-safe across join, travel, respawn, disconnect, and reconnect.
- Clearable or resettable without stale state.
- Diagnosable through logs/evidence without exposing raw private identity.

Any candidate that cannot satisfy these traits remains unresolved or unsafe.

## 3. Forbidden Carrier Candidates Unless Future Evidence Proves Otherwise

The following are forbidden as custom payload channels unless future evidence explicitly proves a safe, non-corrupting path. Current planning should treat them as off limits:

- `Crystals`.
- Keys.
- `HealthInfo`.
- `CurrentHealth` or `CurrentMaxHealth`.
- `WeaponDA`, `AbilityDA`, or `MeleeDA`.
- `Num*Slots`.
- Live inventory arrays.
- `InventoryInfo`.
- `PlayerName`.
- `UniqueId`.
- AutoSave fields.
- Unlock, progression, or currency fields.
- Any field that changes gameplay or persists to save.
- Any field used for identity or matchmaking.
- Any field whose mutation would be visible to users in a misleading way.

This list protects gameplay authority, saves, identity, resources, health, equipment, and inventory from payload hijacking.

## 4. Candidate Classes To Look For

Read-only discovery may look for candidate categories such as:

- Replicated non-authoritative UI/display fields.
- Lobby/player status fields.
- Cosmetic or emote fields.
- Transient player-owned replicated components.
- Non-authoritative text/name/comment/status fields.
- Replicated event payloads that vanilla already sends naturally.
- Pickup, equipment, or inventory notification events as read-only observations.
- Host-visible, client-owned state that is not interpreted as gameplay authority.

Candidate discovery must not become arbitrary object crawling. Each candidate class needs a scoped reason, a narrow read path, and explicit safety tagging.

## 5. Proposed RuntimeProbe Read-Only Phases

These are planning phases only. This task does not implement them.

### `p2p-carrier-discovery-read`

Goal: find candidate fields/classes that might be replicated and non-gameplay-authoritative.

Allowed:

- Read class, name, type, ownership, and visibility metadata only.
- Redact or fingerprint raw/private identity.
- Record safe/unsafe/unresolved classification.

Forbidden:

- Writes.
- RPCs.
- Synthetic payloads.
- Arbitrary object crawling.
- Raw private identity values.

### `p2p-carrier-visibility-watch`

Goal: watch candidate value changes during normal multiplayer play.

Allowed:

- Classify host-to-client, client-to-host, and client-to-client visibility.
- Observe lifecycle behavior during join, travel, respawn, disconnect, and reconnect.
- Record whether candidate values appear stale, reset, or disappear.

Forbidden:

- Writes.
- RPCs.
- Synthetic payloads.
- Identity/save field mutation.

### `p2p-carrier-capacity-read`

Goal: infer observed capacity and cadence only after a candidate is already safe to read.

Allowed:

- Infer observed max length, value type, update cadence, and reset behavior from natural vanilla values.
- Record uncertainty where natural values are insufficient.

Forbidden:

- Synthetic payloads.
- Writes.
- RPCs.
- Expanding scope beyond the already safe candidate path.

### `p2p-carrier-write-smoke`

Goal: future minimal write-smoke only after read discovery, visibility, capacity, and explicit approval.

This phase is explicitly outside RuntimeProbe default behavior and belongs only in a future CrabSyncV2-only sandbox. It must not exist as code until the user explicitly approves it.

Future constraints:

- Tiny sentinel only, for example `CS2_SMOKE_1`.
- Manual disposable test only.
- Clear rollback/abort criteria.
- No production usage.
- No broad writes.
- No RuntimeProbe default mutation.

## 6. `CrabSyncBlock` Strawman

Tiny candidate format:

```text
CS2|v=1|seq=<n>|gen=<n>|kind=<kind>|crc=<crc>|data=<payload>
```

Required parser behavior:

- Ignore malformed blocks.
- Ignore wrong versions.
- Ignore stale `seq` or `gen`.
- Ignore invalid `crc`.
- Never execute arbitrary code.
- Never trust unsupported fields.
- Never treat missing carrier data as proof of zero state.
- Never apply from a carrier block unless the category's read and write evidence gates are also satisfied.

This format is a planning strawman, not proof that a carrier exists and not approval to write a payload anywhere.

## 7. Success And Failure Criteria

Success requires evidence that a candidate:

- Is observed replicated both directions, or enough for a documented host-authoritative P2P model.
- Is not gameplay-critical.
- Can later be safely written and cleared in a sandbox.
- Does not corrupt gameplay, saves, identity, resources, health, equipment, inventory, UI, or matchmaking.
- Has understood lifecycle behavior.
- Has documented capacity and update cadence.

Failure applies when a candidate:

- Is gameplay-critical.
- Is local-only.
- Is host-only when a peer path is required.
- Is too small or unstable.
- Persists harmful data.
- Requires unsafe RPCs or writes.
- Confuses identity, matchmaking, unlocks, save data, UI, or gameplay authority.
- Behaves unpredictably between host and joined client.

## 8. Research Outputs

Future evidence/status output docs may include:

- `docs/P2P_CARRIER_CANDIDATES.md`: candidate list with class/path, reason for review, safety classification, and evidence session links. Future status output, not current proof.
- `docs/P2P_CARRIER_VISIBILITY_MATRIX.md`: host-to-client, client-to-host, client-to-client, join/travel/reset visibility matrix. Future status output, not current proof.
- `docs/P2P_CARRIER_UNSAFE_PATHS.md`: rejected candidates and why they are gameplay-critical, identity-sensitive, save-risky, unstable, or too small. Future status output, not current proof.
- `docs/P2P_CARRIER_WRITE_SMOKE_PLAN.md`: future CrabSyncV2-only sandbox plan for a tiny approved sentinel write, including rollback and abort criteria. Future plan, not current authorization.

Template/status docs now exist for [P2P Carrier Candidates](P2P_CARRIER_CANDIDATES.md), [P2P Carrier Visibility Matrix](P2P_CARRIER_VISIBILITY_MATRIX.md), [P2P Carrier Unsafe Paths](P2P_CARRIER_UNSAFE_PATHS.md), and [P2P Carrier Write-Smoke Plan](P2P_CARRIER_WRITE_SMOKE_PLAN.md). They are not current proof and must not be filled as evidence until the corresponding read-only or sandbox evidence exists.

[P2P Carrier Evidence Mapping](P2P_CARRIER_EVIDENCE_MAPPING.md) defines how future read-only carrier-discovery rows should map into those template/status docs. It is a mapping specification, not an importer or implementation.

[P2P Carrier Discovery Phase Contracts](P2P_CARRIER_DISCOVERY_PHASE_CONTRACTS.md) and [P2P Carrier Safety Gates](P2P_CARRIER_SAFETY_GATES.md) define future read-only phase boundaries and planning gate names. They are not implemented phases or RuntimeProbe configuration changes.

[P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md) defines future decision levels and blocked/eligible outcomes. It does not prove a carrier exists or authorize write-smoke.

## 9. Interaction With Inventory Sync

Inventory item sync can use pure remote visibility only if remote item identity and metadata are proven visible.

If remote visibility fails, a carrier may be needed. A carrier would solve only transport. It would not prove:

- Local item identity.
- `InventoryInfo`.
- `Enhancements`.
- Duplicate same-DA semantics.
- Safe apply paths.
- Joined-client behavior.

Full inventory sync remains blocked until both inventory correctness and any required transport path are proven.

## 10. Interaction With Health And Resources

Health, equipment, crystals, and slots may not need a custom `CrabSyncBlock` if all clients can derive the same result from visible replicated state.

A carrier must not be used to smuggle data through health, crystals, slots, equipment, keys, inventory, or identity fields.

Deterministic client-side math should be preferred before custom payload transport. Custom carrier research is a fallback research path for categories that cannot be solved through visible game-native state.
