# CrabSyncV2 experimental full-sync release

This prerelease packages the standalone CrabSyncV2 UE4SS mod for private,
risk-accepted testing. It is not production-safe. The current supported
deliverable is the deterministic protocol-v2 data plane, game-visible
observation/diagnostics, and offline carrier codec. No runtime carrier, remote
full-inventory visibility, or live apply path is proven. The live configuration
ships disabled with transport/read/carrier/apply/raw-write gates off and
dry-run/backup safeguards on.

Extract the ZIP directly into:

`...\Crab Champions\CrabChampions\Binaries\Win64`

Read `README_INSTALL.txt` and `README_EXPERIMENTAL_FULL_SYNC.txt` before changing
the safe config. The ZIP does not require the legacy CrabInventorySync relay,
Node server, or PowerShell bridge.

## Bundled UE4SS provenance

The package uses the official stable UE4SS `v3.0.1` end-user asset
`UE4SS_v3.0.1.zip`, pinned by SHA-256
`4B47D4BCEDDD2F561A4E395BFA00924CCFC945AF576A2D0C613E6537846C57EC`.
Upstream source and releases:

- https://github.com/UE4SS-RE/RE-UE4SS/tree/v3.0.1
- https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1

UE4SS and CrabSyncV2 are distributed under their respective included MIT
license files. See `UE4SS-ATTRIBUTION.txt` and `RELEASE-MANIFEST.txt` in the ZIP
for the exact source commit, asset URL, and verified runtime hashes.

## Runtime-test status

Packaging and archive integrity are automated. In-game behavior must still be
validated against the manual checklist for the exact tagged build. Codec or
debug-loopback success is not peer transport proof, and deterministic merge is
not an apply plan. Do not infer runtime safety from a successful package or
GitHub Actions run.
