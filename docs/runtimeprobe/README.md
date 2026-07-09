# RuntimeProbe references

This folder contains selected CrabSyncV2 planning, safety, carrier-research, object-dump index, and DataAsset catalog materials imported from [Dudiebug/crabruntimeprobe](https://github.com/Dudiebug/crabruntimeprobe), snapshot `9e214bfc97788721d52a9caf7a4cb635113b1790` on its `main` branch.

`crabruntimeprobe` remains the read-only evidence-collection repository. CrabSyncV2 is the experimental implementation repository. These copies support implementation and private-test planning, but they are not proof that a runtime read, transport, or write path is safe. Treat the design rules, safety matrices, readiness checklists, and unsafe-path documents as binding constraints for experimentation.

The `data/` directory holds the generated latest catalogs for perks, weapon mods, ability mods, melee mods, and relics. Regenerate or refresh evidence in RuntimeProbe, then intentionally copy the relevant changed documents here with provenance noted in the commit.
