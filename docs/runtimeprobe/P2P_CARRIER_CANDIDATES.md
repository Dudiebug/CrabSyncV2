# P2P Carrier Candidates

This is a future template/status document for the CrabSyncV2 P2P carrier research track. It is not current proof that any carrier exists, and it does not authorize RuntimeProbe writes, mutating RPCs, synthetic payloads, or CrabSyncV2 implementation.

No candidate is currently proven.

Future row updates should follow [P2P Carrier Evidence Mapping](P2P_CARRIER_EVIDENCE_MAPPING.md).

Interpret candidate status with [P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md); no row here proves a carrier is approved.

## Candidate Status Values

- `unreviewed`: named for later review, with no evidence classification yet.
- `objectdump-only`: appears in static/objectdump context only; not runtime-safe evidence.
- `read-discovered`: found through read-only runtime discovery with scoped metadata.
- `visibility-confirmed`: read-only evidence shows replicated visibility in one or more required directions.
- `capacity-observed`: natural value capacity/cadence has been observed without synthetic payloads.
- `rejected-gameplay-authoritative`: rejected because the field/event/function is gameplay authority.
- `rejected-local-only`: rejected because visibility does not leave the local client.
- `rejected-identity-risk`: rejected because it affects or exposes identity/matchmaking data.
- `rejected-save-risk`: rejected because it can persist harmful data or affect saves.
- `rejected-unstable`: rejected because lifecycle behavior is stale, inconsistent, or unsafe.
- `write-smoke-candidate`: future only; read/visibility/capacity evidence suggests a manual CrabSyncV2-only sandbox write-smoke may be considered after explicit user approval.

## Candidate Table Columns

Future candidate rows should use these columns:

- Candidate ID.
- Object/Class.
- Field/Event/Function.
- Value kind.
- Owner/source.
- Expected direction.
- Is gameplay-authoritative?
- Is identity-sensitive?
- Is save/persistence-sensitive?
- Observed capacity.
- Observed cadence.
- Lifecycle notes.
- Current status.
- Evidence session.
- Next evidence needed.

## No Approved Candidates Yet

| Candidate ID | Object/Class | Field/Event/Function | Value kind | Owner/source | Expected direction | Is gameplay-authoritative? | Is identity-sensitive? | Is save/persistence-sensitive? | Observed capacity | Observed cadence | Lifecycle notes | Current status | Evidence session | Next evidence needed |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| none | none | none | none | none | unknown | unknown | unknown | unknown | unknown | unknown | No carrier candidate is proven today. | unreviewed | none | Run future read-only carrier discovery. |

## Forbidden Reminder

The following are forbidden as carriers unless future evidence and explicit approval reclassify them:

- `Crystals`.
- Keys.
- `HealthInfo`.
- `CurrentHealth`.
- `CurrentMaxHealth`.
- `WeaponDA`.
- `AbilityDA`.
- `MeleeDA`.
- `Num*Slots`.
- Inventory arrays.
- `InventoryInfo`.
- `PlayerName`.
- `UniqueId`.
- AutoSave fields.
- Unlock, progression, or currency fields.

Normal read evidence for a field does not make it an approved carrier. Payload hijacking remains forbidden unless the carrier research plan, unsafe-path review, and explicit approval say otherwise.
