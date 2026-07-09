# CrabSyncV2 Evidence Baseline

CrabSyncV2 planning must be derived from current RuntimeProbe evidence, objectdump facts, and clearly labeled assumptions. This document summarizes current implications without claiming inventory sync is solved.

## A. Confirmed Runtime-Safe Reads

Current generated evidence confirms `CrabPC.PlayerState` through `GetPropertyValue` in local player-scoped paths.

`CrabPS.WeaponDA`, `CrabPS.AbilityDA`, and `CrabPS.MeleeDA` are confirmed through `GetPropertyValue` as equipment data asset visibility. This does not prove setters, RPCs, or direct field writes.

Slot scalar visibility is confirmed for fields such as `NumWeaponModSlots`, with related slot fields visible in resource evidence. These are scalar reads only.

`CrabPS.Crystals` is confirmed visible through `GetPropertyValue`; resource evidence also mentions keys visibility, but keys are excluded from CrabSyncV2 unless explicitly re-approved.

`CrabPC -> PlayerState -> CrabPS -> HealthInfo` is the currently confirmed player health path. Evidence includes `CurrentHealth`, `CurrentMaxHealth`, `BaseMaxHealth`, and `MaxHealthMultiplier` in player-state-scoped health phases.

PlayerState identity/fingerprint visibility is confirmed with redaction/fingerprinting by default. Raw names/IDs are not normal evidence.

Visible roster source status is currently supported by imported identity evidence: the evidence index reports local identity visible, max visible player count of 2, and roster source resolved. Treat this as identity/roster visibility, not inventory sync proof.

Local inventory array property shape is visible as userdata for `WeaponMods`, `AbilityMods`, `MeleeMods`, `Perks`, and `Relics`. Current safe evidence is strictly shape/userdata metadata. It does not prove count strategy, traversal, element dereference, DA identity, `InventoryInfo`, or `Enhancements`.

[CrabSyncV2 Inventory Item Proof Plan](CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md) defines the planning ladder from shape/count metadata toward item identity, metadata, duplicate semantics, remote visibility, carrier fallback, and write/apply separation. It does not change current evidence facts.

## B. Confirmed Unsafe Or Ambiguous Paths

Unscoped `FindFirstOf(CrabHC)` is ambiguous and has resolved to a non-player health component: `BP_Destructible_ChaoticBarrel10.HC`. Do not use it as the player health source.

The HUD tick hook remains unsafe/restricted and is blocked by default.

The local inventory shallow shape/count phase has crash-suspect history. Later shape confirmation was safer and confirmed property shape without count/traversal, but that does not erase the need for caution around inventory userdata.

`pcall` is not enough protection from native UE4SS access violations. A Lua error boundary cannot make stale native pointers safe.

## C. Unresolved Or Not Yet Proven

- Safe item array traversal.
- Safe element dereference.
- Safe `InventoryInfo` read.
- Safe `Enhancements` read.
- Remote inventory item visibility.
- Joined-client deep reads.
- Joined-client apply/write behavior.
- Official RPC/OnRep call strategy.
- Armor plate sync.
- Keys sync; keys are excluded unless explicitly re-approved.
- Player-owned `CrabHC` discovery.

## D. CrabSyncV2 Design Implication

P2P-style merge appears plausible for crystals, slots, equipment, and possibly health inputs because current evidence shows those categories can be read from visible PlayerState/resource paths.

Inventory sync is not proven by current PlayerState evidence. Inventory may require a proven safe game-native carrier if peer-visible item metadata cannot be established.

CrabSyncV2 should not be built around name-only item sync. Once item reads are proven, CrabSyncV2 should preserve full per-item metadata rather than collapsing items to DA names.
