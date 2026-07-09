CrabSyncV2 EXPERIMENTAL FULL INVENTORY SYNC
===========================================

WARNING
-------

This build is for private testing. It can crash Crab Champions, corrupt or
duplicate an inventory, lose progress, or produce a state the game cannot load.
It is not production-safe and has not been certified for public matchmaking.
Back up your save and inventory before every live-write test.

CrabSyncV2 is a standalone UE4SS mod. This release does not use the legacy
CrabInventorySync Node relay or PowerShell bridge.

WHAT EXISTS IN THIS BUILD
-------------------------

The protocol-v2 core can normalize, preserve, deterministically merge, and
encode/decode candidate snapshots for:

* equipment: weapon, ability, and melee;
* resources: crystals and inventory slot totals;
* arrays: weapon mods, ability mods, melee mods, perks, and relics;
* item identity and metadata: short/full data-asset identity, level,
  accumulated buff, enhancements, and slot/index hints when available.

That data-plane capability is not proof of a runtime P2P transport or apply
path. Current RuntimeProbe evidence supports selected local/PlayerState reads,
not remote full-inventory visibility or any inventory/resource/equipment/health
write. Unsupported or unsafe fields must remain unknown and skipped.

TRANSPORT MODES
---------------

disabled
  No peer transport. Use Scripts\examples\diagnostics-only.txt for local
  diagnostics with all apply gates off.

game_visible
  Converges only from state the game already replicates and CrabSyncV2 can
  safely observe. A missing remote inventory or metadata field stays unknown;
  it is not an empty array or zero. Use p2p-visible-dry-run.txt first.

p2p_carrier
  Exercises carrier candidate discovery and the bounded CrabSyncBlock codec.
  No safe replicated carrier is currently approved or visibility-confirmed, so
  carrier publication/receive are not a working multiplayer transport.

debug_loopback
  Local codec/test plumbing only. It is not evidence that another peer can see
  a payload and it must never authorize apply.

SAFE DEFAULTS
-------------

The release verifier requires `enableCrabSyncV2=false`,
`transportMode=disabled`, every read/carrier/apply/raw-write gate false,
`hostOnlyApply=true`, `dryRunApply=true`, and `backupBeforeApply=true` in the
live config. Profiles under Scripts\examples are never loaded automatically.

TEST IN STAGES
--------------

Stage 0 - Safe startup

1. Leave the shipped config unchanged.
2. Start a solo run and confirm CrabSyncV2 loads without applying anything.
3. Confirm the log prints the build/config/lifecycle summary and no competing
   inventory-sync mod is enabled.

Stage 1 - Read and dry-run plan

1. Copy Scripts\examples\p2p-visible-dry-run.txt over config.txt.
2. Keep dryRunApply=true and allowJoinedClientApply=false. This dry-run profile
   sets allowMultiplayerApply=true so it can compute multiplayer diagnostics;
   dryRunApply is the gate that must prevent every live mutation.
3. Build a small known inventory and capture a snapshot/apply-plan log.
4. Confirm no live values change and no backup is falsely reported as applied.

Stage 2 - Unsupported-path confirmation

1. Confirm logs explicitly report that full remote inventory visibility,
   carrier I/O, and apply/write paths are unproven or blocked.
2. Confirm codec success or debug loopback never upgrades those capabilities.
3. Do not enable raw writes merely to make this stage appear successful.

Stage 3 - Dangerous disposable host experiment

Scripts\examples\experimental-full-p2p-sync.txt contains the actual V2 full
host-test keys. It uses game_visible transport, enables raw/apply gates, and
sets dryRunApply=false. This build implements guarded best-effort writes for
current/max health, equipment through ServerEquipInventory, crystals/slots,
and scalar/enhancement metadata when a unique full-identity pairing exists.
Identity replacement, raw array rebuild, armor/base-health writes, ambiguous
duplicates, incomplete reads, and multiplayer inventory apply remain blocked.
Use it only after every prior gate passes, rollback has been exercised, and the
save is disposable.

Stage 4 - Private multiplayer

Do not proceed until solo mutation is repeatable and rollback has been tested.
Joined-client apply remains false in every shipped profile. Carrier transport,
remote inventory visibility, and multiplayer apply are not currently proven.
This build can attempt non-inventory host-side categories when all gates pass;
multiplayer inventory apply remains blocked without a stable origin ledger.
Test only in a private session, with every player backed up and using the exact
same release/config.

STOP CONDITIONS
---------------

Immediately disable CrabSyncV2 if you see a crash loop, stale or cross-session
payload, duplicate ambiguity, identity/path mismatch, unexpected item removal,
wrapped or negative resource values, missing enhancements, an apply before the
lifecycle is stable, or a live write while dryRunApply=true.

Collect the evidence listed in README_INSTALL.txt and follow
CRABSYNCV2_MANUAL_TEST_CHECKLIST.md before reporting results.
