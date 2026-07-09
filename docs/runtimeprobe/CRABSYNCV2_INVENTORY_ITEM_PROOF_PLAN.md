# CrabSyncV2 Inventory Item Proof Plan

This document is planning-only. It does not authorize RuntimeProbe writes, CrabSyncV2 implementation, inventory apply, mutating RPCs, full traversal, or local UE4SS runtime work.

## 1. Purpose

Define the proof ladder required before CrabSyncV2 item sync exists.

Item sync is not ready. Current evidence proves only local inventory array shape, userdata wrapper visibility, and count metadata. Item contents, item identity, item metadata, remote visibility, duplicate semantics, and apply behavior remain unproven.

Transport, read correctness, metadata preservation, duplicate semantics, and write/apply safety are separate gates. Passing one gate never promotes another gate automatically.

Unsupported is a valid safe result. A phase that cleanly proves "not available through this path" is better than widening scope into unsafe traversal.

Future CrabModFramework inventory wrappers must follow this proof ladder through capability declarations. Unsupported or unavailable inventory capabilities must skip rather than falling back to raw UE4SS traversal.

Inventory item sync readiness is also gated by [CrabSyncV2 Readiness Checklist](CRABSYNCV2_READINESS_CHECKLIST.md). This proof plan is necessary for inventory readiness, but it is not sufficient for apply/write readiness by itself.

Each future proof rung should close with [Phase Handoff Template](PHASE_HANDOFF_TEMPLATE.md), including what was proven, what remains unsupported, and which no-cross boundaries still apply.

## 2. Current Evidence Baseline

Local array properties are visible:

- `WeaponMods`.
- `AbilityMods`.
- `MeleeMods`.
- `Perks`.
- `Relics`.

Userdata wrappers are visible for those local PlayerState inventory properties.

`pcall(#value)` count metadata is confirmed for local wrappers. Count metadata is wrapper metadata only.

Count metadata is not traversal proof.

Count metadata is not item identity proof.

Count metadata is not `InventoryInfo` proof or `Enhancements` proof.

The current selected/next phase is `inventory-element-da-read`.

Remote inventory item visibility remains unresolved. Prior multiplayer resource visibility showed better evidence for resources/equipment/health than inventory item contents.

## 3. Required Proof Ladder

| Rung | What It Proves | What It Does Not Prove | Required Next Step | Unsafe Assumption To Avoid |
|---|---|---|---|---|
| Shape proof | The five local inventory properties can be read as present values or safe unsupported values. | Count, traversal, element access, identity, metadata, or apply. | Userdata wrapper proof. | Assuming visible property shape means array contents are safe. |
| Userdata wrapper proof | Returned values can be classified as wrappers/userdata without dereferencing contents. | Count correctness, element wrappers, or safe iteration. | Count metadata proof. | Treating userdata visibility as item visibility. |
| Count metadata proof | A narrow wrapper length/count observation can succeed or fail safely. | Traversal, element dereference, item identity, `InventoryInfo`, `Enhancements`, or sync readiness. | First-element wrapper proof. | Treating `#value` as permission to loop. |
| First-element wrapper proof | At most one first element per non-empty local array can be obtained or marked unsupported under a dedicated gate. | Full traversal, multiple elements, metadata, remote visibility, or apply. | First-element DA identity proof. | Expanding from one first element to every element. |
| First-element DA identity proof | The first local element's category-specific DA field can be read or safely reported unsupported. | Full array identity coverage, metadata preservation, duplicate semantics, or write safety. | First-element full DA path proof if safe. | Assuming one item proves all item classes and indices. |
| First-element full DA path proof, if safe | Full DA identity/path can be captured for the first element when the path is safe and redacted as needed. | That full paths are always available, stable, or safe for all elements. | `InventoryInfo` scalar proof. | Falling back to raw/private object crawling for paths. |
| `InventoryInfo` scalar proof | `InventoryInfo` parent visibility can be checked on a proven item path. | `Level`, `AccumulatedBuff`, `Enhancements`, writes, or persistence semantics. | `Level` proof. | Assuming `InventoryInfo` exists on every item or can be fabricated. |
| `Level` proof | `InventoryInfo.Level` can be read, classified, and clamped where observed. | Default level for unknown items, apply safety, or upgrade semantics. | `AccumulatedBuff` proof. | Defaulting unknown `Level` to `1` as if observed. |
| `AccumulatedBuff` proof | `InventoryInfo.AccumulatedBuff` can be read and finite-checked where observed. | Non-negative assumptions, merge policy, or apply safety. | Enhancement shape/count proof. | Defaulting unknown `AccumulatedBuff` to `0` as if observed. |
| Enhancement shape/count proof | `Enhancements` shape and count can be read or marked unsupported under a dedicated phase. | Enhancement values, ordering semantics, or safe mutation. | Enhancement value proof. | Treating unknown enhancements as an empty list. |
| Enhancement value proof | Individual enhancement values can be read through a capped safe path or marked unsupported. | Merge/union policy, write safety, or full traversal beyond the cap. | Full capped iteration proof. | Unioning enhancements before representation is understood. |
| Full capped iteration proof | A bounded iteration strategy can read multiple local elements without instability. | Unbounded traversal, remote reads, joined-client safety, or apply. | Duplicate/same-name semantics proof. | Treating capped iteration as unlimited traversal. |
| Duplicate/same-name semantics proof | Same-DA and same-name item cases can be represented without accidental collapse. | That duplicates are stack-only or safe to merge. | Slot/index stability proof. | Collapsing duplicate items by name or DA. |
| Slot/index stability proof | Index/slot can be used only if stable across lifecycle and category behavior. | That reorder-only changes require apply. | Joined-client replay proof. | Treating array index as durable identity without evidence. |
| Joined-client replay proof | Proven local reads remain safe for joined-client contexts under matching gates. | Joined-client apply, new deeper reads, or host authority. | Remote visibility proof. | Assuming solo/host-like proof applies to joined clients. |
| Remote visibility proof | Remote PlayerState item identity and metadata are visible, unavailable, or unsupported. | Local item read safety, carrier readiness, or apply safety. | P2P carrier fallback proof only if remote visibility fails. | Assuming resource visibility implies inventory item visibility. |
| P2P carrier fallback proof, only if remote visibility fails | A safe non-gameplay carrier can transport item payloads after carrier readiness review. | Local item reads, metadata proof, duplicate semantics, or writes. | Write/apply proof, separate from RuntimeProbe. | Treating carrier transport as a cure for unsafe item reads. |
| Write/apply proof, separate from RuntimeProbe | Future CrabSyncV2-only evidence may identify an approved apply path after passive observation and sandbox review. | RuntimeProbe mutation or production safety by default. | Human-reviewed implementation planning. | Reusing v1 traversal/apply behavior without proof. |

## 4. Item Identity Model

An item identity row should include:

- Category.
- Local array property.
- Wrapper struct or wrapper value kind.
- DA field:
- `WeaponMods -> WeaponModDA`.
- `AbilityMods -> AbilityModDA`.
- `MeleeMods -> MeleeModDA`.
- `Perks -> PerkDA`.
- `Relics -> RelicDA`.
- Short DA name.
- Preferred full DA path if safe.
- Slot/index only if stability is proven.
- Source proof status.
- Lifecycle generation.
- Player fingerprint/source.
- Local vs remote visibility class.

Identity rows must preserve unsupported markers. A missing field, unsafe field, or unresolved visibility class is not a real item value.

## 5. Metadata Model

The planned metadata model includes:

- `InventoryInfo`.
- `Level`.
- `AccumulatedBuff`.
- `Enhancements`.
- Finite/range assumptions.
- Unsupported/unknown representation.

Missing metadata must not be treated as real default metadata unless evidence proves that default.

Do not default unknown `Level` to `1` as if observed.

Do not default unknown `Enhancements` to empty as if observed.

Do not default unknown `AccumulatedBuff` to `0` as if observed.

Unknown must stay unknown until evidence proves otherwise. A merge planner may mark an item incomplete, unsupported, or observe-only; it must not silently invent metadata.

## 6. Duplicate And Merge Risk

The same DA may or may not be stack-only.

Do not collapse duplicate same-name items until representation is proven.

Do not union enhancements unless semantics are proven.

Do not max `Level` or `AccumulatedBuff` unless semantics are proven.

Preserve per-instance metadata.

Deterministic ordering must be based on proven identity fields only.

Reorder-only changes should not trigger destructive apply.

Duplicate semantics need dedicated evidence before merge policy. Until then, same-name and same-DA duplicates remain separate unresolved instances or force observe-only behavior.

## 7. Remote Inventory Problem

Previous multiplayer resource visibility showed remote inventory arrays unresolved, nil, or error-like while resources, equipment, and health had better visibility.

Remote item metadata is not proven.

P2P item sync requires either:

- Remote item identity and metadata visibility.
- A safe `CrabSyncBlock` carrier plus local item metadata proof on each peer.

Carrier only solves transport.

Carrier does not solve local item read safety.

Carrier does not solve apply/write safety.

Carrier data must not be trusted for an item category whose local read, metadata, duplicate, lifecycle, or apply gates are not met.

## 8. Interaction With P2P Carrier Docs

Relevant docs:

- [CrabSyncV2 P2P Carrier Research Plan](CRABSYNCV2_P2P_CARRIER_RESEARCH_PLAN.md).
- [P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md).
- [P2P Carrier Unsafe Paths](P2P_CARRIER_UNSAFE_PATHS.md).

Carrier readiness cannot promote inventory proof rungs. It cannot turn count metadata into traversal proof, first-element proof into full iteration proof, or unknown metadata into observed metadata.

Carrier must not use inventory arrays, `InventoryInfo`, or `Enhancements` as custom payload fields.

Carrier cannot authorize live apply.

Carrier data must be ignored for item categories whose read/apply evidence gates are not met.

Future capability names for these gates are tracked in [CrabModFramework Capability Model](CRABMODFRAMEWORK_CAPABILITY_MODEL.md).

## 9. Interaction With Write-Path Docs

Relevant docs:

- [CrabSyncV2 Safe Write Path Discovery](CRABSYNCV2_SAFE_WRITE_PATH_DISCOVERY.md).
- [Write Path Ledger](WRITE_PATH_LEDGER.md).
- [Write Path Unsafe Paths](WRITE_PATH_UNSAFE_PATHS.md).
- [Write Path Evidence Mapping](WRITE_PATH_EVIDENCE_MAPPING.md).

Item read proof does not authorize item writes.

Inventory apply requires separate official-path or write-path evidence.

Raw inventory rebuild remains unsafe until metadata preservation and official path behavior are proven.

`InventoryInfo` and `Enhancements` writes remain unsafe until future sandbox evidence.

RuntimeProbe must not perform write/apply tests.

## 10. Phase Plan

| Phase | Purpose | What It May Observe | Forbidden | Likely Result Statuses |
|---|---|---|---|---|
| `inventory-element-da-read` | Check first-element local DA identity feasibility. | At most one first element per non-empty local category and its category DA field if safe. | Full traversal, multiple elements, `InventoryInfo`, `Enhancements`, `Level`, `AccumulatedBuff`, writes, RPCs. | `confirmed`, `unsupported`, `partial`, `crash-suspect`. |
| `inventoryinfo-scalar-read` | Check safe metadata parent and scalar access. | `InventoryInfo`, `Level`, `AccumulatedBuff` on proven item path. | Enhancements traversal, writes, RPCs, invented defaults. | `confirmed`, `unsupported`, `partial`, `blocked-parent-missing`, `crash-suspect`. |
| `enhancements-read` | Check enhancement shape/count/value through staged subphases. | Shape, count, and later capped values only after prior gates. | Bulk traversal, union policy, writes, RPCs. | `confirmed`, `unsupported`, `partial`, `ambiguous-semantics`, `crash-suspect`. |
| `inventory-capped-iteration-read` | Expand from first-element proof to bounded local iteration. | Capped local element identities and metadata already proven safe. | Unbounded traversal, remote traversal, apply. | `confirmed`, `unsupported`, `partial`, `cap-insufficient`, `crash-suspect`. |
| `inventory-duplicate-semantics-read` | Understand same-name and same-DA representation. | Duplicate rows, per-instance metadata, stack-like markers if visible. | Collapsing, maxing, unioning, writes. | `confirmed`, `unresolved`, `unsupported`, `ambiguous-semantics`. |
| `inventory-slot-index-stability-read` | Determine whether slot/index can be identity or ordering metadata. | Index/order across lifecycle-safe snapshots. | Treating reorder as apply trigger, writes. | `stable`, `unstable`, `unsupported`, `lifecycle-dependent`. |
| `joined-client-inventory-element-da-read` | Replay proven first-element identity reads as joined client. | Same narrow reads already proven locally. | New depth, full traversal, writes, RPCs. | `confirmed`, `unsupported`, `partial`, `role-unsafe`, `crash-suspect`. |
| `joined-client-inventoryinfo-scalar-read` | Replay proven metadata scalar reads as joined client. | Same proven metadata scalar reads. | Enhancements unless separately proven, writes, RPCs. | `confirmed`, `unsupported`, `partial`, `role-unsafe`, `crash-suspect`. |
| `remote-inventory-visibility-read` | Determine whether remote item surfaces are visible at all. | Capped remote PlayerState inventory visibility markers. | Unsafe deep traversal, writes, RPCs, raw identity leakage. | `remote-visible`, `remote-unavailable`, `partial`, `unsupported`, `crash-suspect`. |
| `remote-inventory-element-da-read` | Determine whether remote item DA identity is visible. | Capped remote identity only after remote visibility proof. | Metadata reads unless separately gated, full traversal, writes. | `confirmed`, `unsupported`, `partial`, `visibility-missing`, `crash-suspect`. |
| `remote-inventoryinfo-visibility-read` | Determine whether remote metadata is visible. | Remote `InventoryInfo` scalar visibility only after identity proof. | Enhancements unless separately gated, writes, RPCs. | `confirmed`, `unsupported`, `partial`, `visibility-missing`, `crash-suspect`. |
| `p2p-inventory-carrier-design-review` | Decide whether carrier design is needed if remote visibility fails. | Carrier readiness docs, capacity/lifecycle evidence, and item proof status. | Treating carrier as item read proof, live payload writes, gameplay-field carrier use. | `not-needed`, `blocked-no-carrier`, `blocked-item-proof`, `candidate-review-only`. |
| `inventory-write-path-observation` | Passively observe natural inventory write/apply paths. | Function/event names and natural before/after state where available. | Calling functions, mutating fields, synthetic writes, RPCs. | `naturally-observed`, `unsupported`, `candidate-row`, `unsafe`, `crash-suspect`. |
| `inventory-apply-sandbox` | Future CrabSyncV2-only apply smoke after explicit approval. | One tiny approved sandbox candidate with rollback/abort criteria. | RuntimeProbe mutation, broad inventory rebuild, production use. | `proposed`, `approved`, `passed-once`, `failed`, `unsafe`. |

## 11. Acceptance Criteria Before CrabSyncV2 Item Sync

- Local item DA identity proven.
- Local full identity/path strategy documented.
- Local `InventoryInfo` metadata proven.
- `Enhancements` proven or explicitly unsupported with design consequence.
- Duplicate/same-name semantics documented.
- Slot/index stability documented or rejected.
- Joined-client safety replayed.
- Remote visibility solved or safe carrier decision made.
- Merge semantics documented.
- Apply/write path separately proven.
- Crash-suspect blockers resolved.
- Docs regenerated and reviewed.
- No keys/unlocks/progression coupling.
- No server/bridge fallback unless explicitly re-approved by the user.

Missing any required item keeps item sync blocked or observe-only.

## 12. Unsupported Outcomes

| Unsupported Outcome | Safe Fallback |
|---|---|
| First-element DA read unsupported. | Disable item sync for that category; keep shape/count evidence as observe-only diagnostics and require future research. |
| `InventoryInfo` unsupported. | Treat metadata as unknown; do not apply or merge items that require metadata preservation. |
| `Enhancements` unsupported. | Treat enhancements as unknown, not empty; omit upgrade-sensitive sync or keep category observe-only. |
| Remote inventory visibility unsupported. | Use local observe-only planning, or consider carrier design review only after local item metadata proof. |
| Duplicate semantics unresolved. | Do not collapse duplicates; keep item sync disabled or per-instance observe-only. |
| Carrier unavailable. | Do not invent transport; leave P2P item sync blocked if remote visibility is insufficient. |
| Apply path unsafe. | Disable apply; diagnostics and read-only convergence may continue if read evidence is clean. |

Unsupported outcomes should be recorded explicitly. They are not failures of the safety model; they are safe stopping points.

## 13. Relationship To v1

v1 item payload modeling is useful as a schema reference because it emphasized metadata-aware item comparison.

v1 traversal, read, and apply behavior is not automatically trusted.

v1 merge by name, max value, or enhancement union must not be copied until the game representation is proven.

v1 server/bridge transport is not carried forward. That architecture remains v1-only archival context and is out of scope for CrabSyncV2 unless explicitly re-approved by the user.

v2 starts from RuntimeProbe proof, not v1 behavior.
