CrabSyncV2 writes mandatory pre-apply .cs2 snapshots into this directory.

Do not edit a backup in place. The restore helper is experimental and obeys
the same lifecycle, role, category, raw-write, and dry-run gates as apply.
Generated .cs2 files are intentionally excluded from source and release ZIPs.
