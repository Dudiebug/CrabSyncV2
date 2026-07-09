# CrabSyncV2

CrabSyncV2 is an **experimental, CrabSyncV2-only** UE4SS mod for private Crab Champions testing. It is P2P/game-native first: it observes game-replicated state and contains an experimental carrier research path. It does **not** use the legacy relay/server, PowerShell bridge, `push_*.json` or `recv_*.json` IPC, room codes, or `crab.dudiebug.net`.

The shipped configuration is disabled and non-mutating by default. This is not a claim that every read, transport, or write path is safe. Back up saves before any test and use only private sessions.

## Status

The core can model and deterministically merge candidate snapshots for health, equipment, crystals, slots, inventory items, and item metadata/enhancements. It can also produce diagnostics, serialize the bounded carrier codec, and make gated dry-run plans.

Remote full-inventory visibility, a safe replicated carrier, and live multiplayer inventory writes remain unproven. Safe defaults keep all reads, carrier I/O, and writes off; joined-client apply is off in every shipped profile.

## Repository layout

- `client/Mods/CrabSyncV2/` — the mod, safe config, examples, and backup marker.
- `docs/` — implementation, release, vendor-drop, and manual-test documentation.
- `docs/runtimeprobe/` — selected evidence and planning material imported from the read-only [crabruntimeprobe](https://github.com/Dudiebug/crabruntimeprobe) repository.
- `scripts/`, `tests/`, and `.github/workflows/` — packaging, verification, core tests, and CI.

The source `client/Mods/mods.txt` enables only CrabSyncV2 and UE4SS's required Keybinds mod. Release packaging uses `packaging/CrabSyncV2-mods.txt`, which also enables only those two entries.

## Test

Run the Lua core test with Lua 5.4:

```powershell
lua5.4 tests/crabsyncv2_core_test.lua
./scripts/test-crabsyncv2-core.ps1 -LuaExe C:\path\to\lua.exe
```

CI runs this test on pushes and pull requests. Experimental release tags matching `v*-experimental` run the test, build a ZIP, verify its contents and safety gates, and publish a prerelease.

## Package and install

Build a release ZIP from the repository root:

```powershell
./scripts/package-crabsyncv2-release.ps1 -OutputDirectory ./dist -Version v0.0.0-experimental
./scripts/verify-crabsyncv2-release.ps1 -ZipPath ./dist/CrabSyncV2-v0.0.0-experimental-Win64.zip
```

The packager downloads the pinned UE4SS runtime unless you provide a verified archive or vendor drop. It includes the V2 mod, UE4SS runtime files, safe config, examples, install/experimental warnings, licensing, attribution, and a release manifest. It rejects legacy sync mods, relays, bridges, IPC payloads, logs, and backups.

For game installation and rollback instructions, read [README_INSTALL.txt](README_INSTALL.txt). Start with `Scripts/examples/diagnostics-only.txt` or `p2p-visible-dry-run.txt`; do not use the dangerous full-sync profile without completing the manual checklist.

## Logs and disable

Collect `UE4SS.log`, any CrabSyncV2 diagnostic/breadcrumb output, the effective config with sensitive details removed, role (solo/host/joined), and a backup path if one was reported. To disable the mod, close the game and set `CrabSyncV2 : 0` in `Mods/mods.txt` (or remove `Mods/CrabSyncV2`).

## Licensing

CrabSyncV2 is MIT licensed in [LICENSE](LICENSE). UE4SS is distributed only under its own license and attribution: [UE4SS-LICENSE.txt](UE4SS-LICENSE.txt) and [UE4SS-ATTRIBUTION.txt](UE4SS-ATTRIBUTION.txt).
