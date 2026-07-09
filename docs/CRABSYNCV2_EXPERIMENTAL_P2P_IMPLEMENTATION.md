# CrabSyncV2 Experimental P2P Implementation

## Status and evidence boundary

This document describes the experimental CrabSyncV2 data plane implemented in
`client/Mods/CrabSyncV2/Scripts/main.lua`. It is intentionally separate
from the CrabInvSync v1 PowerShell bridge and Node relay. CrabSyncV2 does not use
the bridge, relay, room password, dashboard, or push/receive files as transport
or authority.

The code can normalize snapshots, derive a deterministic read-only merged view,
and encode/decode candidate `CrabSyncBlock` frames. Those are pure local
operations. They do **not** prove that a safe replicated game carrier exists.
The current RuntimeProbe carrier catalog has no approved candidate, no useful
visibility matrix, and no write-smoke approval. Runtime carrier I/O therefore
stays disabled. A working codec is not permission to write its output into a
gameplay, identity, save, inventory, equipment, health, resource, or slot field.

The evidence baseline comes from these `Dudiebug/crabruntimeprobe` documents:

- `SAFE_ACCESS_MATRIX.md`
- `CRABSYNCV2_DESIGN_RULES.md`
- `CRABSYNCV2_IMPLEMENTATION_BLUEPRINT.md`
- `CRABSYNCV2_READINESS_CHECKLIST.md`
- `CRABSYNCV2_P2P_ARCHITECTURE.md`
- `CRABSYNCV2_V1_MIGRATION_DOCTRINE.md`
- `CRABSYNCV2_HEALTH_P2P_MODEL.md`
- `CRABSYNCV2_RESOURCE_P2P_MODEL.md`
- `CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md`
- `CRABSYNCV2_P2P_CARRIER_RESEARCH_PLAN.md`
- `P2P_CARRIER_READINESS_CHECKLIST.md`
- `P2P_CARRIER_SAFETY_GATES.md`
- `P2P_CARRIER_UNSAFE_PATHS.md`
- `P2P_CARRIER_VISIBILITY_MATRIX.md`

The RuntimeProbe evidence currently supports selected PlayerState-scoped reads,
not full inventory traversal or writes. In particular, local array wrapper/count
evidence is not item metadata proof, and a carrier is transport only: it cannot
upgrade the evidence status of a read or apply path.

## Architecture

The experimental path has five deliberately separable stages:

1. **Lifecycle-scoped observation** creates a local row only while the local
   PlayerState, role, and generation are stable.
2. **Snapshot normalization** converts an untrusted observation or decoded block
   into a bounded protocol-v2 snapshot while retaining unsupported/unknown state.
3. **Peer selection** rejects stale, future-dated, partial, wrong-version, and
   malformed rows, then chooses one row per source deterministically.
4. **Read-only convergence** derives the same category view on clients that see
   the same accepted rows. A mismatch is diagnostic evidence, not a write plan.
5. **Carrier codec** serializes and chunks a snapshot for offline and future
   carrier testing. No game field is selected or written by the codec.

An apply planner and best-effort executor are present for private experimental
testing, but are inert by default and are not evidence that a write path is safe.
They require the global apply gate plus category-specific, role, lifecycle,
multiplayer, dry-run, backup, and low-level write/function gates. Unsupported or
ambiguous categories are skipped with a reason. Any future claim of safe apply
still requires category read proof, write-path evidence, disposable sandbox
approval, role/lifecycle coverage, and an explicit capability review.

## Snapshot protocol v2

The normalized envelope is a Lua table with this shape:

```lua
{
    protocolVersion = 2,
    sessionId = "session fingerprint",
    clientInstanceId = "launch-local identifier",
    sourcePlayerFingerprint = "redacted stable-in-session fingerprint",
    sourceRole = "host|joined|solo|unknown",
    lifecycleGeneration = 4,
    timestampMs = 1730000000000,
    tick = 120,
    visibilityClass = "local_only|peer_visible|host_only_candidate|unresolved",
    evidenceConfidence = "runtime_safe_local|runtime_safe_remote_visible|unresolved|unsafe",
    transportMode = "game_visible|p2p_carrier|debug_loopback",
    partial = false,
    health = { ... },
    equipment = { ... },
    resources = { ... },
    inventory = { ... },
    unsupportedFields = { ... },
    carrier = { ... },
}
```

Identity values are session-scoped fingerprints. Raw player names, account IDs,
and matchmaking IDs do not belong in a snapshot or carrier block.

### Health

Health rows use the evidence-approved source beginning at
`CrabPC -> PlayerState -> CrabPS -> HealthInfo`:

```lua
health = {
    supported = true,
    currentHealth = 100.0,
    currentMaxHealth = 150.0,
    baseMaxHealth = 100.0,
    maxHealthMultiplier = 1.5,
    previousHealth = nil,
    previousMaxHealth = nil,
    armorSupported = false,
    unsupportedFields = { "armor" },
}
```

Missing or non-finite values stay `nil` and are reported as unsupported. The
normalizer never turns an unknown health value into zero. Unscoped `CrabHC`
observations are not accepted as player-health provenance.

The object-dump-backed bindings used by the implementation are:

- `CrabPS.HealthInfo.CurrentHealth`, `CurrentMaxHealth`, `PreviousHealth`, and
  `PreviousMaxHealth`;
- `CrabPS.BaseMaxHealth` and `CrabPS.MaxHealthMultiplier`;
- observed-only `HealthInfo.CurrentArmorPlates`, `CurrentArmorPlateHealth`, and
  `PreviousArmorPlateHealth` (retained as evidence, never converged/applied).

### Equipment and resources

Equipment rows retain both short and full DA identities when observed. Resource
normalization clamps the objectdump-backed integer fields:

- equipment: `CrabPS.WeaponDA`, `AbilityDA`, and `MeleeDA`;
- crystals: `CrabPS.Crystals`, UInt32 `0..4294967295`;
- slots: `NumWeaponModSlots`, `NumAbilityModSlots`, `NumMeleeModSlots`, and
  `NumPerkSlots`, Byte `0..255`.

Keys are always excluded (`keysSupported=false`). Unknown resources remain
unknown; the clamp applies only to an observed numeric value.

### Inventory items

Each item is a per-instance row, not a name-keyed count:

```lua
{
    category = "weaponMods",
    sourcePlayer = "peer fingerprint",
    visibilityClass = "local_only",
    lifecycleGeneration = 4,
    index = 0,
    daShortName = "DA_WeaponMod_Example",
    daFullName = "/Game/.../DA_WeaponMod_Example.DA_WeaponMod_Example",
    level = 3,
    levelKnown = true,
    accumulatedBuff = -12.5,
    accumulatedBuffKnown = true,
    enhancements = { 1, 4, 7 },
    enhancementsKnown = true,
    metadataStatus = "ok",
    unsupportedFields = {},
}
```

The five categories are `weaponMods`, `abilityMods`, `meleeMods`, `perks`, and
`relics`. Full DA identity is preferred when it exists; the short name is a
fallback/display identity. Index is a snapshot hint, not durable identity unless
later evidence proves index stability.

Those categories bind to `CrabPS.WeaponMods`, `AbilityMods`, `MeleeMods`,
`Perks`, and `Relics`; each slot uses its category DA field (`WeaponModDA`,
`AbilityModDA`, `MeleeModDA`, `PerkDA`, or `RelicDA`) plus
`InventoryInfo.Level` (Byte), `InventoryInfo.AccumulatedBuff` (Float), and
`InventoryInfo.Enhancements` (`TArray<ECrabEnhancementType>`). The observed enum
range is `None=0` through `Random=27`: Bouncing, Accelerating, Zigging,
Spiraling, Snaking, Returning, Orbiting, Chipping, Sticky, Growing, Freezing,
Flaming, Electrifying, Toxifying, Arcanifying, Persisting, Doubling, Targeting,
Damaging, Booming, Tripling, Splitting, Scattering, Expanding, Homing,
Endangering, and Random in values `1..27` respectively.

Unknown metadata is represented explicitly:

- unknown level: `level=nil`, `levelKnown=false`
- unknown accumulated buff: `accumulatedBuff=nil`,
  `accumulatedBuffKnown=false`
- unknown enhancements: `enhancements=nil`, `enhancementsKnown=false`
- observed empty enhancements: `enhancements={}`,
  `enhancementsKnown=true`

Signed finite accumulated buffs are preserved. Duplicate same-name and same-DA
items remain separate rows with their own metadata. The normalizer and merge do
not synthesize level `1`, buff `0`, or empty enhancements for unknown fields.
They also do not max levels/buffs or union enhancements across instances; the
RuntimeProbe inventory proof plan explicitly leaves those semantics unresolved.

## Normalization contract

`normalizeSnapshot(raw, nowMs)` treats every input as untrusted and produces a
bounded row. When `nowMs > 0`, it also enforces freshness using the observer's
clock; merge admission and carrier assembly repeat that boundary check.

It must:

- require `protocolVersion == 2`;
- require lifecycle generation and timestamp; merge admission additionally
  requires a usable source fingerprint and the expected session fingerprint;
- reject timestamps more than 5 seconds in the future;
- reject snapshots older than 15 seconds by default;
- reject non-finite numeric values;
- require explicit protocol, timestamp, and lifecycle generation fields;
- clamp crystals, slot counts, item levels, indices, and other
  objectdump-backed integer fields to their documented ranges, while rejecting
  an invalid generation or carrier envelope;
- preserve signed finite accumulated buffs;
- retain enhancement array order and per-instance association;
- mark an entire enhancement sequence unknown if any element is sparse,
  non-integral, or outside the proven enum range `0..27`;
- retain `nil` for unknown metadata and carry unsupported markers forward;
- retain `partial=true` so merge can reject an incomplete transport/read;
- ignore executable values and unsupported table shapes.

Normalization is idempotent: normalizing an already normalized snapshot at the
same logical time produces an equivalent snapshot.

## Deterministic merge contract

`mergeSnapshots(rows, nowMs, expectedSessionId, expectedGeneration)` is a convergence function, not
an apply planner. It returns a merged read-only view and a report containing
accepted and rejected rows plus the policy names used. Runtime callers supply
their current session ID and lifecycle generation; a row with a missing or
different session fingerprint, or a different generation, is rejected so
reconnect/travel residue cannot cross sessions.

### Admission and one-row-per-source selection

Rows are normalized before use. Wrong-version, cross-session, malformed, partial, more than
5-seconds future-dated, or more than 15-seconds stale rows are rejected with a
reason. For multiple accepted rows from
one source, selection uses this deterministic precedence:

1. Transport trust: `game_visible` before `p2p_carrier` before
   `debug_loopback`.
2. Higher lifecycle generation.
3. Newer timestamp.
4. A stable canonical tie-break independent of Lua table iteration order.

Input order must never change the result. A lower-trust or stale row cannot
overwrite a safer current game-visible row.

### Category policies

The initial experimental policies are intentionally explicit in the merge
report:

| Category | Policy | Meaning |
|---|---|---|
| Health | `max_visible` | Take the maximum finite supported values. This avoids positive feedback when peers already expose converged state. A summed pool remains diagnostics-only and is not a vanilla fact. |
| Equipment | `lowest_fingerprint` | For each weapon/ability/melee field, select the first supported row after stable fingerprint ordering. This is view-invariant and does not let an unsupported field in one row erase a later visible observation. |
| Crystals | `max_visible` | Take the maximum selected observed value and clamp to UInt32, avoiding repeated summation of already shared observations. This is not currency apply proof. |
| Slots | `max_visible` | Take the maximum observed byte value because slot contribution semantics remain unresolved. |
| Inventory | `preserve_instances` | Preserve every per-source item instance, including cross-peer exact duplicates, because no evidence authorizes collapsing them. The resulting diagnostic union is deterministic, but multiplayer inventory apply is blocked until a stable origin/contribution ledger can prevent feedback multiplication. |

An exact inventory record contains category, source fingerprint, preferred full
DA identity (or observed short-name fallback), known level, signed buff,
enhancement sequence, and the observed index hint. Two identical rows seen on
two peers remain two records with separate provenance. Unsupported or partial
categories remain unsupported. Missing carrier data is never proof of zero or
an empty inventory. Category output does not authorize writes.

## Carrier block codec

### Read-only carrier discovery results

The first implementation probes a deliberately narrow candidate catalog and
logs local/host/joined/remote visibility, value kind, capacity, lifecycle,
criticality, and status. No candidate is writable or approved:

| Candidate | Why inspected | Current status |
|---|---|---|
| `CrabPS.PlayerTintType` | replicated cosmetic/display enum | unproven; user-visible |
| `CrabPS.CrabSkin` | cosmetic DataAsset | blocked; save/user-visible |
| `PlayerState.Score` | replicated display scalar | unsafe; gameplay-authoritative |
| `PlayerState.CompressedPing` | replicated transient scalar | unsafe; network-authoritative |
| `CrabPS.IslandRewardRarity` | replicated status enum | unsafe; gameplay-authoritative |

Crystals, keys, health, equipment DAs, slot counts, inventory arrays,
`InventoryInfo`, names/IDs, AutoSave, progression, currency, and unlock fields
are excluded before discovery and are never carrier storage.

The codec uses a deterministic length-prefixed typed serialization. The binary
payload is converted to uppercase hexadecimal so the frame remains text-safe.
The codec does not evaluate code, deserialize functions, or accept arbitrary Lua
objects.

`encodeCarrierBlocks(snapshot, opts)` supports `seq`, `generation`,
`chunkBytes` (default `96`), and `maxBlockBytes`. Each emitted frame is:

```text
CS2|v=2|id=<crc-seq-gen>|seq=<n>|gen=<n>|part=<i>|total=<n>|crc=<8HEX>|data=<HEX>
```

`data` is last. `part` is one-based. All chunks for one message share the same
message ID, sequence, generation, total, and eight-digit uppercase Adler-32 checksum. The checksum is
computed for the complete serialized payload, not independently per chunk.

`decodeCarrierBlock` validates frame grammar and bounds but does not make a
single chunk authoritative. `assembleCarrierBlocks` additionally rejects:

- wrong protocol versions;
- malformed or oversized fields;
- mixed message IDs, sequences, generations, totals, or checksums;
- duplicate part numbers;
- missing or out-of-range parts;
- invalid or lowercase hex/checksum payload data (the protocol is uppercase);
- checksum mismatches;
- typed-payload decode failures;
- source/envelope generation disagreement;
- partial, future-dated, or stale decoded snapshots.

Only a complete, valid, fresh assembly is normalized and returned. A failed assembly
has no partially trusted result. Replay protection at the eventual transport
boundary must also maintain a per-source `(generation, seq)` high-water mark;
the pure codec alone cannot know a peer's prior accepted sequence.

Adler-32 is an accidental-corruption check, not authentication. A future hostile
peer model would require an authenticated design before carrier use.

## Apply planner/executor boundary

The planner compares the normalized local snapshot to the merged candidate by
category and full item metadata. It records equipment, resource, item identity,
level, accumulated-buff, enhancement, duplicate, unknown-metadata, and unsafe
pairing mismatches before any mutation is considered.

The executor is a deliberately gated best-effort experiment:

- `enableCrabSyncV2`, `allowApply`, and the relevant category gate must be true;
- `dryRunApply` must be false;
- lifecycle, PlayerState, generation, role, joined-client, multiplayer, and
  host-only gates must all pass;
- `backupBeforeApply` must be true and the backup write must succeed before any
  real mutation; disabling or failing backup blocks apply;
- official-function calls and raw scalar writes each require their own explicit
  low-level gate; `allowRawInventoryWrites` is reserved for evidence work and
  cannot override the identity-replacement/array-rebuild block;
- metadata and enhancements require their separate gates and unambiguous
  full-identity pairing;
- multiplayer inventory writes, identity replacement, array rebuild, ambiguous
  duplicates, and incomplete category reads are blocked in this build;
- unsupported/unknown metadata, ambiguous duplicates, and unproven array rebuilds
  are skipped and logged rather than filled with defaults;
- `debug_loopback` is diagnostics-only and can never authorize apply; the
  currently carrier-less `p2p_carrier` mode also blocks apply globally;
- any `sum_visible` health/crystal/slot policy is diagnostics-only and
  hard-blocked from live apply to prevent feedback growth;
- optional `OnRep_Inventory`, `OnRep_Crystals`, and UI refresh calls stay behind
  their own gates.

The implemented mutation candidates are raw `HealthInfo.CurrentHealth` /
`CurrentMaxHealth`, `CrabPS.ServerEquipInventory(WeaponDA, AbilityDA, MeleeDA)`,
raw clamped `Crystals`/slot properties, and `InventoryInfo` scalar/enhancement
writes only for a complete unique full-identity match. Base health, multiplier,
armor, inventory identity replacement, and array resize/rebuild are not written.

This executor is not production-safe. Its existence does not relax the evidence
boundary or authorize enabling its gates in a normal install.

## Runtime safety gates

The implementation must remain inert unless the selected experimental v2 config
gate is enabled. Even then:

- unknown role, startup, loading, travel, respawn, join/disconnect transition,
  unstable PlayerState, or generation change suspends snapshot work;
- peer-visible and category/deep-item reads remain separately gated, while
  joined-client and multiplayer mutation have additional role gates;
- carrier write and apply gates default false;
- `Crystals`, keys, `HealthInfo`, slots, equipment DA fields, inventory arrays,
  `InventoryInfo`, identity fields, and save fields are forbidden carriers;
- a codec round-trip or debug loopback must not promote carrier readiness;
- no carrier or merged value may trigger apply without separate category proof.

## Test hook and offline test mode

Setting `_G.CRABSYNCV2_TEST_MODE=true` before loading `main.lua` exposes the pure
core without starting UE4SS hooks, timers, bridge launch, file transport, or
runtime object reads:

```lua
_G.CrabSyncV2.test.normalizeSnapshot(raw, nowMs)
_G.CrabSyncV2.test.mergeSnapshots(rows, nowMs, expectedSessionId, expectedGeneration)
_G.CrabSyncV2.test.encodeCarrierBlocks(snapshot, opts)
_G.CrabSyncV2.test.decodeCarrierBlock(block)
_G.CrabSyncV2.test.assembleCarrierBlocks(blocks, nowMs)
```

Run the repository test harness from the repository root with Lua 5.4:

```powershell
./scripts/test-crabsyncv2-core.ps1 -LuaExe C:\path\to\lua.exe
```

The harness covers required envelope fields, wrong/stale/future/cross-session/
cross-generation snapshots, scalar and level clamps, signed health/buff
preservation, enhancement preservation and invalid-sequence rejection, unknown
metadata, independent duplicate instances, input-order-independent merge,
carrier provenance and bounds, multi-chunk round-trip, duplicate/missing/mixed
chunks, partial/generation-mismatched envelopes, and CRC corruption.

## What remains blocked

- No carrier candidate is currently approved or even visibility-confirmed.
- Remote full inventory identity/metadata visibility is not proven.
- Duplicate stack semantics and slot/index durability are unresolved.
- Stable item-origin/contribution provenance is unavailable, so multiplayer
  inventory apply is explicitly blocked to prevent feedback multiplication.
- Inventory metadata writes and enhancement-array writes are not proven.
- Resource, equipment, health, and inventory apply paths are experimental and
  not proven safe; unsupported operations are expected to skip.
- Joined-client apply is not proven.
- The codec has no authentication and no runtime carrier binding.

These blockers do not invalidate the pure data-plane implementation or its
tests. They mean the current safe default is an experimental, deterministic,
offline-verifiable P2P core with carrier I/O and apply disabled. Enabling the
best-effort executor is an explicit private-testing risk, not a readiness claim.
