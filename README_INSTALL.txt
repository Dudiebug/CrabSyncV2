CrabSyncV2 EXPERIMENTAL INSTALL
===============================

This ZIP is laid out for the Crab Champions Win64 directory. It includes a
verified UE4SS v3.0.1 runtime and the standalone CrabSyncV2 mod. It does not
need the legacy CrabInventorySync relay server or PowerShell bridge.

INSTALL
-------

1. Close Crab Champions.
2. Back up your current Win64 folder and any existing UE4SS Mods folder.
3. Extract every file in this ZIP directly into:

   ...\Steam\steamapps\common\Crab Champions\CrabChampions\Binaries\Win64

   After extraction, dwmapi.dll and UE4SS.dll must be directly inside Win64.
   Do not extract the ZIP into an extra CrabSyncV2 or release-name folder.
4. Confirm these files exist:

   dwmapi.dll
   UE4SS.dll
   UE4SS-settings.ini
   Mods\mods.txt
   Mods\CrabSyncV2\Scripts\main.lua
   Mods\CrabSyncV2\Scripts\config.txt
5. Read README_EXPERIMENTAL_FULL_SYNC.txt before editing the configuration.
6. Launch the game. The shipped config is intentionally non-mutating; inspect
   the UE4SS log before enabling any experimental apply gate.

IMPORTANT UPGRADE NOTE
----------------------

UE4SS 3.x uses dwmapi.dll and UE4SS.dll. If an older UE4SS 2.x install left an
xinput1_3.dll in Win64, move that old file out of the game directory before
launching. The official UE4SS v3.0.1 release notes warn that leaving it in place
can crash the game.

ENABLE / DISABLE
----------------

The release-specific Mods\mods.txt enables CrabSyncV2 and does not enable the
legacy CrabInventorySync or CrabSyncV1 mods. To disable CrabSyncV2, close the
game and change this line:

   CrabSyncV2 : 1

to:

   CrabSyncV2 : 0

Do not enable two inventory-sync mods at the same time.

CONFIGURATION
-------------

Edit:

   Mods\CrabSyncV2\Scripts\config.txt

Use the profiles in:

   Mods\CrabSyncV2\Scripts\examples

Start with diagnostics-only.txt or p2p-visible-dry-run.txt. The
experimental-full-p2p-sync.txt profile is a dangerous host-test profile with
live-write gates and dryRunApply=false; do not copy it over the safe config
until the implementation guide says the intended path is supported and you are
using a disposable, backed-up save.

ROLLBACK / UNINSTALL
--------------------

1. Close the game.
2. Set CrabSyncV2 : 0 in Mods\mods.txt, or remove Mods\CrabSyncV2.
3. Restore the Win64/Mods backup made before installation if you replaced an
   existing UE4SS setup.
4. Live apply creates a serialized `.cs2` snapshot under
   `Mods\CrabSyncV2\Scripts\backups` before mutation. The runtime exposes the
   gated debug helper `_G.CrabSyncV2.restoreBackup(path)`; it obeys the same
   lifecycle, role, category, raw-write, and dry-run gates as normal apply.
   This is an experimental recovery aid, not a proven save-repair mechanism.

SUPPORT EVIDENCE
----------------

When reporting a problem, include the release tag, UE4SS.log, the CrabSyncV2
log/breadcrumb output, the effective config with sensitive details removed,
whether the run was solo/host/joined, and any reported backup path. Do not
publish private session details.

Licenses and upstream provenance are in LICENSE-CrabSyncV2.txt,
UE4SS-LICENSE.txt, UE4SS-ATTRIBUTION.txt, and RELEASE-MANIFEST.txt.
