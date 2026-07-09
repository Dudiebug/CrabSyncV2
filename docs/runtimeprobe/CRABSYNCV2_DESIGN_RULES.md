# CrabSyncV2 Design Rules

These are future CrabSyncV2 constraints. They do not authorize RuntimeProbe writes.

CrabSyncV2 should use future CrabModFramework capability-gated wrappers where possible. See [CrabModFramework API Contract](CRABMODFRAMEWORK_API_CONTRACT.md) and [CrabModFramework Capability Model](CRABMODFRAMEWORK_CAPABILITY_MODEL.md).

[CrabSyncV2 Readiness Checklist](CRABSYNCV2_READINESS_CHECKLIST.md) is the gate for starting any v2 behavior at a selected maturity level. A [Phase Handoff Template](PHASE_HANDOFF_TEMPLATE.md) handoff should close every future phase.

## Runtime/Lifecycle

- No apply/write during unknown role, startup, loading, travel, respawn, join, disconnect, or unstable local player state.
- Require stable PlayerState and stable generation for multiple ticks before trusting reads.
- Joined clients default to read-only/no-apply until specific joined-client evidence proves safety.
- Reset stale snapshot/apply state on role/lifecycle transitions.

## Health

- Player health source must start with `CrabPC -> PlayerState -> CrabPS -> HealthInfo`.
- Do not use unscoped `FindFirstOf(CrabHC)` for player health.
- Pooled/shared health is a CrabSyncV2 design concept, not a vanilla RuntimeProbe fact.
- Multiplayer max-health math remains evidence-gated.
- Armor policy remains unresolved until documented evidence exists.
- Health P2P planning must follow [CrabSyncV2 Health P2P Model](CRABSYNCV2_HEALTH_P2P_MODEL.md): read-only convergence first, no `HealthInfo` carrier use, and no health apply until every apply gate is satisfied.

## Inventory

- Inventory item planning must follow [CrabSyncV2 Inventory Item Proof Plan](CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md).
- Do not compare inventory arrays by DA name only.
- Do not rebuild item arrays unless full `InventoryInfo` can be preserved.
- Item identity must eventually include DA short name, preferably full DA identity/path if safe, `Level`, `AccumulatedBuff`, and `Enhancements`.
- `InventoryInfo.Level` is byte-like and must be clamped safely.
- `Enhancements` are required for Anvil upgrade preservation.
- `AccumulatedBuff` must be finite and should not be assumed non-negative unless evidence proves it.
- Duplicate same-name items must not be collapsed unless the game representation proves same-DA entries are stack-only.
- Reordering alone should not trigger destructive apply.
- Count metadata and first-element identity proof do not authorize full traversal or item sync.
- Unknown `Level`, `AccumulatedBuff`, or `Enhancements` must stay unknown rather than being treated as observed defaults.

## Resources

- Slot fields are byte range and must clamp to `0..255`.
- Crystals are UInt32 range and must clamp to `0..4294967295`.
- Keys must not sync unless explicitly re-approved.
- Resource/equipment P2P planning must follow [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md): visible-state derivation first, no crystals/slots/equipment/keys carrier use, and no apply until separate write-path gates are satisfied.

## P2P Merge

- CrabSyncV2 baseline is P2P/game-native first.
- No bridge/server/JSON IPC transport for v2 baseline.
- Do not emit values outside objectdump-backed property ranges.
- Do not let stale peer-visible state overwrite safer local runtime state.
- Prefer generation/timestamp/role-aware merge policy over blind last-write-wins.
- Separate local-only, peer-visible, host-authoritative-candidate, and unresolved fields.

## Carrier Safety

- Do not hijack gameplay-authoritative fields as custom payload channels.
- Prohibited payload channels include gameplay-critical values such as `Crystals`, keys, `HealthInfo`, slot counts, equipment DA fields, identity fields, inventory arrays, or AutoSave data.
- [P2P Carrier Unsafe Paths](P2P_CARRIER_UNSAFE_PATHS.md) records forbidden carrier paths and must be checked before any future carrier status can advance.
- [CrabSyncV2 P2P Carrier Research Plan](CRABSYNCV2_P2P_CARRIER_RESEARCH_PLAN.md) is the only approved planning path toward a future `CrabSyncBlock` carrier; it does not prove or authorize a carrier today.
- [P2P Carrier Safety Gates](P2P_CARRIER_SAFETY_GATES.md) defines future planning gate names; no carrier gate may enable RuntimeProbe writes or RPCs.
- [P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md) must be satisfied before any future `CrabSyncBlock` design depends on a carrier.
- Custom `CrabSyncBlock` carrier work requires:
  1. Dedicated carrier-discovery/read phase.
  2. Evidence review and explicit gate approval.
  3. Later gated write-smoke phase outside RuntimeProbe default behavior.

## RPCs/Writes

- RuntimeProbe must not call mutating RPCs.
- Safe write/apply planning must follow [CrabSyncV2 Safe Write Path Discovery](CRABSYNCV2_SAFE_WRITE_PATH_DISCOVERY.md): passive observation first, manual CrabSyncV2-only sandbox later, and no RuntimeProbe write behavior.
- CrabModFramework write capabilities are future/experimental and unavailable today; read capabilities do not authorize writes.
- [Write Path Evidence Mapping](WRITE_PATH_EVIDENCE_MAPPING.md) defines future passive evidence mapping rules. Mapping function presence, natural observation, or read evidence into status docs does not approve writes.
- [Write Path Ledger](WRITE_PATH_LEDGER.md) and [Write Path Unsafe Paths](WRITE_PATH_UNSAFE_PATHS.md) must be reviewed before any future apply/write path advances.
- CrabSyncV2 may test official RPCs separately only behind explicit safety gates and with manual test phases.
- Raw writes should be fallback only after official paths are proven unusable.
- OnRep/UI refresh behavior must be tested before relying on it.
