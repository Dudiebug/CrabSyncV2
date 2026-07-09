# CrabSyncV2 experimental release manual test checklist

Record the release tag, game build, UE4SS version, Windows version, role
(solo/host/joined), config hash, and save-backup location with every run. Keep
the raw logs; a verbal “worked” result is not sufficient evidence.

## 1. Package and install gate

- [ ] Run `scripts/verify-crabsyncv2-release.ps1` against the exact ZIP.
- [ ] Confirm the verifier reports UE4SS v3.0.1 loader/runtime hashes, direct
      Win64 layout, safe config, separate experimental example, both licenses,
      attribution, manifest integrity, and no relay/server/bridge content.
- [ ] Back up the Crab Champions save and existing Win64/Mods directories.
- [ ] Extract into `CrabChampions\Binaries\Win64` and confirm there is no extra
      wrapper directory.
- [ ] Confirm `CrabSyncV2 : 1` is the only enabled inventory-sync mod.
- [ ] Confirm no legacy `xinput1_3.dll` remains from UE4SS 2.x.

## 2. Safe-default startup

- [ ] Launch solo with the shipped `config.txt` unchanged.
- [ ] Confirm the log shows the expected release/build version and safe gates.
- [ ] Confirm no inventory/resource/equipment value changes.
- [ ] Confirm no network/relay/bridge process is required or launched.
- [ ] Travel to the lobby, start/end a run, and return to the lobby without a
      lifecycle crash or an apply during transition.

## 3. Dry-run read and plan

- [ ] Copy `Scripts/examples/p2p-visible-dry-run.txt` over `config.txt`; do not
      start with the live-write `experimental-full-p2p-sync.txt` profile.
- [ ] Verify equipment identity reads for weapon, ability, and melee.
- [ ] Verify crystals and each slot total read without wraparound.
- [ ] Record which weapon/ability/melee mod, perk, and relic arrays are actually
      visible locally and remotely. Current evidence does not prove remote full
      inventory visibility.
- [ ] Where an item is actually observed, verify short identity, full
      identity/path, level, signed accumulated buff, enhancements, and
      slot/index hint; record every unsupported/unknown field.
- [ ] Confirm unsupported fields are explicitly marked/logged rather than
      silently replaced with plausible defaults.
- [ ] Feed pure/offline test snapshots with mismatches and confirm convergence
      preserves identity, level, buff, enhancement, order, and duplicates. Do
      not treat this as proof of peer visibility or an apply plan.
- [ ] Confirm reorder-only input does not become an unsafe destructive rewrite.
- [ ] Confirm dry-run produces no live writes.

## 4. Carrier boundary (currently expected to remain blocked)

- [ ] Run the carrier codec multi-chunk round-trip in offline test mode.
- [ ] Confirm CRC/chunk/sequence/generation failures reject the whole assembly.
- [ ] Confirm `debug_loopback` is labeled local-only and never becomes peer proof.
- [ ] Run the read-only carrier-discovery profile and record candidate/visibility
      evidence. No candidate is currently approved.
- [ ] Confirm carrier publish/receive stays closed without visibility and
      write-smoke approval.
- [ ] Confirm gameplay, identity, save, inventory, health, equipment, resource,
      crystal, and slot fields are never selected as carrier storage.

## 5. Apply boundary (dangerous best-effort executor)

Safe-default and dry-run profiles must explicitly skip every mutation. The live
profile is only for a disposable, backed-up host test; implemented does not mean
runtime-proven or production-safe.

- [ ] Confirm current/max health can only use the raw-property gate; base max,
      multiplier, and armor remain modeled but skipped with exact reasons.
- [ ] Confirm equipment can only call `ServerEquipInventory` when the full DA
      identity resolves and the official-function gate is enabled.
- [ ] Confirm crystals/slots require the resource and raw-property gates and
      remain clamped to UInt32/Byte ranges.
- [ ] Confirm scalar metadata/enhancements require unique complete full-identity
      pairing plus their separate gates.
- [ ] Confirm inventory identity replacement, raw array rebuild, duplicates,
      incomplete categories, and multiplayer inventory apply remain blocked.
- [ ] `allowOfficialFunctionApply`, `allowRawPropertyWrites`, and
      `allowRawInventoryWrites` do not bypass missing category proof.
- [ ] OnRep/UI-refresh gates cannot authorize a write by themselves.
- [ ] Disabling backup or failing the mandatory pre-apply backup blocks every write.
- [ ] Confirm values outside supported ranges are clamped/rejected as designed.
- [ ] Confirm ambiguous duplicate pairing skips mutation with an exact reason.
- [ ] Confirm the dangerous `experimental-full-p2p-sync.txt` profile is clearly
      labeled unproven and is never loaded automatically.

## 6. Lifecycle and stale-state tests

- [ ] Receive or queue an observed/decoded snapshot during lobby/run travel;
      confirm it is rejected or deferred until the same lifecycle generation is
      stable.
- [ ] Reset/restart the mod and confirm old state cannot apply in the new session.
- [ ] Exercise rapid inventory changes during reads and confirm partial/empty
      transient arrays are not published or applied as authoritative state.
- [ ] Confirm crash breadcrumbs identify the last completed phase.

## 7. Private multiplayer (only after all solo gates pass)

- [ ] Every tester uses the identical ZIP and effective config.
- [ ] Start host-only, joined-client read/apply disabled.
- [ ] Confirm role detection is stable and unknown roles cannot mutate.
- [ ] Confirm no cross-room/session state is accepted.
- [ ] Confirm `game_visible` includes only genuinely replicated observations and
      never fabricates missing remote inventory/metadata as empty or zero.
- [ ] Confirm `p2p_carrier` remains discovery/codec-only until a carrier passes
      visibility, collision, lifecycle, and write-smoke approval.
- [ ] Enable multiplayer non-inventory gates one at a time and verify ownership
      without double counting; confirm inventory remains ledger-blocked.
- [ ] Confirm disconnect/rejoin/travel cannot replay stale state.
- [ ] Stop immediately on duplication, loss, crash, or an unexpected role apply.

## 8. Evidence bundle

- [ ] Release ZIP filename and SHA-256.
- [ ] `RELEASE-MANIFEST.txt` and verifier output.
- [ ] Effective config with private codes/secrets removed.
- [ ] UE4SS and CrabSyncV2 logs from startup through shutdown/crash.
- [ ] Before, planned, after, and rollback snapshots.
- [ ] Exact reproduction steps and observed/expected result.
- [ ] Explicit list of fields/categories not runtime-tested.
