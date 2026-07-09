# Offline UE4SS vendor-drop fallback

The CrabSyncV2 packager normally downloads the pinned official end-user asset:

- release: `v3.0.1`
- asset: `UE4SS_v3.0.1.zip`
- SHA-256: `4B47D4BCEDDD2F561A4E395BFA00924CCFC945AF576A2D0C613E6537846C57EC`

The version is intentionally pinned. Do not substitute `experimental-latest`, a
development (`zDEV`) asset, a mirror, or a same-named archive from another site.

For an offline build, use one of these options:

1. Pass the exact official archive explicitly:

   ```powershell
   ./scripts/package-crabsyncv2-release.ps1 `
     -UE4SSArchivePath C:\vendor\UE4SS_v3.0.1.zip `
     -Offline
   ```

2. Place the exact archive at
   `vendor/ue4ss/v3.0.1/UE4SS_v3.0.1.zip` and run with `-Offline`.

3. Pass an expanded official v3.0.1 Win64 drop with
   `-UE4SSVendorRoot C:\vendor\ue4ss-v3.0.1 -Offline`. The repository's tracked
   `client` directory is the default expanded fallback.

Every path is verified before use. Archives must match the full pinned asset
hash. Expanded drops must contain the exact pinned hashes for `dwmapi.dll`,
`UE4SS.dll`, Keybinds, and UEHelpers. A partial or modified drop fails closed.
The packager never copies CrabInventorySync, a bridge, server files, or arbitrary
content from the vendor root.
