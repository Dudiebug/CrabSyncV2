# CrabSyncV2 Crash Safety

UE4SS Lua `pcall` is useful for ordinary Lua errors, but it does not guarantee safety against native access violations. A UObject can look reachable to Lua while the underlying native object is stale, partially constructed, destroyed, or unsafe to touch through the selected bridge method.

Stale/null/partially constructed UObject access is especially dangerous during join, load, travel, respawn, disconnect, and replication. Those are exactly the windows where PlayerState, inventory arrays, nested structs, and replicated fields may be changing under the mod.

## Joined-Client Crash Hypothesis

The joined-client crash class should be treated as likely invalid/stale/native object access until proven otherwise.

Possible causes include a small offset read from a bad pointer, nested object/property/TArray access during an unstable lifecycle window, or dereference of a wrapper whose parent UObject was no longer valid. This hypothesis does not prove which field caused a crash; it defines the safety posture CrabSyncV2 must take.

## Required Mitigations

- Stable context gate.
- Stable PlayerState gate.
- Stable role gate.
- Stable inventory generation gate.
- Warmup ticks before trusting runtime reads.
- No apply on unknown role.
- No joined-client writes until proven safe.
- No nested array/item/`InventoryInfo` access until each parent layer is separately proven safe.
- Reset stale state on join, travel, respawn, disconnect, role changes, PlayerState changes, and generation changes.

## Forbidden Assumptions

- `pcall` makes native access safe.
- Objectdump presence means runtime safe.
- Local solo proof means joined-client proof.
- Property shape visibility means safe traversal.
- Count visibility means safe item metadata.
- Health component presence means player health.
