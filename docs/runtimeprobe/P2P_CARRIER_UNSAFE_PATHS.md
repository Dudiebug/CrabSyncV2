# P2P Carrier Unsafe Paths

This is a future status document for rejected or forbidden P2P carrier paths. It is pre-seeded with known forbidden carrier classes from the carrier research plan.

These entries do not mean normal read access is unsafe. They mean custom payload hijacking is unsafe or forbidden for CrabSyncV2 carrier planning unless future evidence and explicit approval reclassify a path.

Future row updates should follow [P2P Carrier Evidence Mapping](P2P_CARRIER_EVIDENCE_MAPPING.md).

Use [P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md) for rejection and blocked-status decisions.

## Unsafe Reason Taxonomy

- `gameplay-authoritative`.
- `currency/progression`.
- `identity/matchmaking`.
- `save-persistent`.
- `health/gameplay critical`.
- `equipment authority`.
- `inventory authority`.
- `UI/user-visible deception risk`.
- `local-only`.
- `unstable lifecycle`.
- `requires mutating RPC`.
- `unknown ownership`.

## Unsafe Path Table

| Path ID | Object/Class | Field/Event/Function | Unsafe reason | Evidence basis | Current status | Notes |
|---|---|---|---|---|---|---|
| carrier-forbidden-crystals | `CrabPS` or resource state | `Crystals` as custom carrier | gameplay-authoritative; currency/progression | Carrier research plan forbidden list; resource value affects gameplay/economy. | forbidden-template | Normal read visibility does not approve payload use. |
| carrier-forbidden-keys | `CrabPS` or resource state | Keys as custom carrier | gameplay-authoritative; currency/progression | Carrier research plan forbidden list; key state affects gameplay/progression. | forbidden-template | Keys are excluded from sync unless explicitly re-approved and cannot carry payloads. |
| carrier-forbidden-healthinfo | `CrabPS` | `HealthInfo` as custom carrier | health/gameplay critical | Carrier research plan forbidden list; health state affects survival/gameplay. | forbidden-template | Read-only health evidence is not carrier approval. |
| carrier-forbidden-current-health | `CrabPS.HealthInfo` | `CurrentHealth`/`CurrentMaxHealth` as custom carrier | health/gameplay critical | Carrier research plan forbidden list; values directly affect gameplay. | forbidden-template | Pooled health planning does not authorize payload mutation. |
| carrier-forbidden-equipment-da | `CrabPS` | `WeaponDA`/`AbilityDA`/`MeleeDA` as custom carrier | equipment authority | Carrier research plan forbidden list; equipment identity affects gameplay/loadout. | forbidden-template | Equipment DA visibility is for read-only convergence planning only. |
| carrier-forbidden-slots | `CrabPS` | `Num*Slots` as custom carrier | gameplay-authoritative | Carrier research plan forbidden list; slot counts affect inventory capacity/gameplay. | forbidden-template | Slot clamping does not authorize payload mutation. |
| carrier-forbidden-live-inventory-arrays | `CrabPS` or inventory owner | Live inventory arrays as custom carrier | inventory authority; save-persistent | Carrier research plan forbidden list; inventory contents and ordering are gameplay/save sensitive. | forbidden-template | Inventory array reads remain separately gated and unproven for deep use. |
| carrier-forbidden-inventoryinfo | Inventory item metadata | `InventoryInfo` as custom carrier | inventory authority; save-persistent | Carrier research plan forbidden list; metadata preserves item level/buffs/upgrades. | forbidden-template | Metadata proof is needed for item correctness, not transport hijacking. |
| carrier-forbidden-identity | `PlayerState` or identity surfaces | `PlayerName`/`UniqueId` as custom carrier | identity/matchmaking; UI/user-visible deception risk | Carrier research plan forbidden list; identity values are private/user-facing and matchmaking-relevant. | forbidden-template | Raw identity remains redacted/fingerprinted by default. |
| carrier-forbidden-autosave | Save/autosave owner | AutoSave fields as custom carrier | save-persistent | Carrier research plan forbidden list; mutation can persist harmful data. | forbidden-template | No save field should carry payloads. |
