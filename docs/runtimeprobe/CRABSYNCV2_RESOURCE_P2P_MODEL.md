# CrabSyncV2 Resource P2P Model

This document is planning-only. It does not authorize RuntimeProbe writes, CrabSyncV2 implementation, resource apply, mutating RPCs, custom carrier use, or local UE4SS runtime work.

## 1. Purpose

Define the future P2P resource/equipment model for CrabSyncV2 from currently documented RuntimeProbe visibility.

This is architecture and read-convergence planning only. It does not authorize writes, apply behavior, custom carrier use, mutating RPCs, or gameplay-critical field hijacking.

## 2. Current Evidence

Equipment DataAsset visibility is documented for:

- `WeaponDA`.
- `AbilityDA`.
- `MeleeDA`.

Crystal visibility is documented for:

- `Crystals`.

Slot scalar visibility is documented for:

- `NumWeaponModSlots`.
- `NumAbilityModSlots`.
- `NumMeleeModSlots`.
- `NumPerkSlots`.

Remote visibility exists or is plausible for these categories based on existing resource visibility docs. Keys may be visible in some resource visibility evidence, but they remain out of scope and must not be synced.

Current evidence supports read-only P2P derivation and convergence planning. It does not support resource mutation, equipment mutation, slot mutation, crystal apply, or custom carrier use.

## 3. Equipment Model

Equipment DA identities are visible through PlayerState-scoped reads.

Source rows should include:

- Local equipment snapshot.
- Remote equipment snapshot.
- Role/context/generation.
- Timestamp.
- Source proof.

All DA identity values must remain evidence-scoped. Object identity visibility does not prove setters, RPCs, direct writes, or durable apply behavior.

Policy options:

- Observe-only: ready as a read-only planning concept if source rows remain stable.
- Host-authoritative equipment view: not ready; requires topology evidence and future apply/write proof.
- Latest visible change, only after event evidence: not ready; requires passive event evidence for natural changes and stale-row rules.
- Local-only equipment: safest non-sync policy; remote rows may be diagnostics/display only.

Apply remains blocked. Official write paths require future safe write-path discovery and CrabSyncV2-only sandbox review before any implementation discussion.

Equipment DA fields are forbidden as custom carriers.

## 4. Crystals Model

`Crystals` is a UInt32-range scalar:

`0..4294967295`

Remote crystal scalar visibility appears available or plausible through visible PlayerStates.

Policy options:

- Observe-only: safest current policy.
- Sum visible contributions: not ready; requires deterministic ownership, lifecycle, and progression policy.
- Max: not ready; may be useful for diagnostics but can misrepresent currency/progression state.
- Host-authoritative: not ready; requires host visibility, authority policy, write-path evidence, and explicit approval.
- Local-only: safest non-sync policy if currency/progression risk remains unacceptable.

Do not sync keys.

Do not use `Crystals` as a custom carrier.

Crystal apply remains blocked until write-path evidence exists. `OnRep_Crystals` is observation-only until future proof; function or event presence does not authorize calls.

## 5. Slot Model

Slot fields are byte-range scalars:

`0..255`

Visible scalar counters include:

- `NumWeaponModSlots`.
- `NumAbilityModSlots`.
- `NumMeleeModSlots`.
- `NumPerkSlots`.

Unresolved slot semantics:

- Unlocked slots.
- Locked slots.
- Total/max slots.
- UI slots.
- Persistence across transition.
- Whether values are contribution counters or effective capacity.

Policy options:

- Observe-only: safest current policy.
- Sum contributions if proven: not ready; requires proof these fields are contribution counters.
- Max visible value: not ready; may be a display/convergence candidate only.
- Host-authoritative: not ready; requires topology, lifecycle, and write-path evidence.

Slot apply is not proven. `ServerIncrementNumInventorySlots` remains candidate/write-path research only and must not be called by RuntimeProbe.

`Num*Slots` fields are forbidden as custom carriers.

## 6. Keys Policy

Keys may be visible, but do not sync them.

Reason:

- Keys are unlock/progression currency.
- Key sharing creates gameplay/account progression risk.
- The user explicitly wants keys excluded.

Keys are forbidden as a custom carrier.

Keys remain out of CrabSyncV2 scope unless explicitly re-approved.

## 7. Deterministic Client-Side Math

All clients should derive the same merged output from the same visible inputs.

Inputs must include:

- Player fingerprint.
- Role.
- Lifecycle generation.
- Timestamp.
- Source proof.
- Visibility class.

Stale or partial players must be excluded by generation/visibility policy. Missing or unsupported rows should produce explicit unsupported markers.

A mismatch means convergence failure, not permission to write.

All scalar values must be clamped before convergence math. Crystals clamp to `0..4294967295`; slot scalars clamp to `0..255`.

## 8. P2P Without CrabSyncBlock

Health, equipment, crystals, and slots may not need a custom payload if visible replicated state is enough.

Prefer visible-state derivation before carrier transport.

Carrier is a fallback for missing hidden metadata only. It is not a shortcut around read proof, convergence proof, write-path proof, sandbox review, or explicit approval.

## 9. P2P With CrabSyncBlock

Only consider this if a future carrier exists.

A carrier only solves transport. It does not authorize resource apply, equipment apply, crystal apply, slot apply, or health apply.

A carrier must not use gameplay-critical fields. `Crystals`, keys, equipment DA fields, slot counts, health fields, identity fields, and inventory fields remain forbidden as custom payload carriers.

The carrier readiness checklist applies before any design can depend on `CrabSyncBlock`.

## 10. Apply/Write Boundaries

Each category keeps separate gates:

- Read/convergence gate: category-specific visible-state rows are stable, source-scoped, clamped, generation-aware, and deterministic.
- Transport gate if needed: future evidence proves a carrier safe for transport without using gameplay-critical fields.
- Write-path gate: passive observation and write-path ledger evidence identify a candidate path without RuntimeProbe mutation.
- Sandbox smoke gate: future CrabSyncV2-only, disposable, explicitly approved, and not RuntimeProbe.
- Production gate: future only, requiring repeated stability, lifecycle coverage, rollback/abort policy, UI/persistence proof, and explicit capability gates.

Equipment apply, crystal apply, slot apply, and any resource apply remain blocked until the relevant gates are satisfied.

## 11. Open Questions And Next Phases

- `p2p-resource-convergence-read`: verify deterministic convergence inputs for equipment, crystals, and slots.
- `p2p-equipment-convergence-read`: verify stable local/remote DA identity rows and role/generation behavior.
- `p2p-crystals-convergence-read`: verify crystal scalar visibility, clamping, and lifecycle behavior.
- `p2p-slots-convergence-read`: verify slot scalar visibility, clamping, and stale-row behavior.
- `slot-model-read`: resolve unlocked, locked, max, total, UI, persistence, and contribution-vs-capacity semantics.
- `resource-write-path-observation`: passive only; observe natural resource changes without calling functions or mutating fields.
- `equipment-write-path-observation`: passive only; observe natural equipment changes and OnRep/event behavior.
- `slot-write-path-observation`: passive only; observe natural slot changes and candidate official paths without calls.
