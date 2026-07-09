# CrabSyncV2 Readiness Checklist

This is the master readiness checklist for CrabSyncV2 planning. It is documentation-only and does not prove runtime behavior, authorize RuntimeProbe writes, call mutating RPCs, implement CrabSyncV2, or implement CrabModFramework.

## 1. Purpose

Define when CrabSyncV2 work may begin at each maturity level.

Readiness is split into separate gates:

- Documentation readiness.
- Read-only prototype readiness.
- Deterministic convergence readiness.
- P2P carrier/transport readiness.
- Write/apply readiness.
- Production readiness.

This checklist does not prove any runtime behavior. It only describes what evidence and docs must exist before a selected CrabSyncV2 maturity level can begin.

CrabSyncV2 is not ready for full inventory sync today. RuntimeProbe remains read-only.

## 2. Start Condition

CrabSyncV2 code may start only when all start conditions for the selected readiness level are satisfied:

- P2P architecture docs are complete.
- v1 migration doctrine is complete.
- RuntimeProbe docs prove the safe read paths required for the selected v2 level.
- P2P visibility/carrier strategy is decided for the selected feature set.
- Safe write-path discovery methodology is documented.
- Unsupported behaviors are documented.
- CrabModFramework API/capability docs exist.
- Phase handoff process exists.
- No crash-suspect blocker applies to the selected feature set.

Meeting the general start condition does not mean full sync is ready. The selected feature set still needs its category-specific gates.

## 3. Readiness Levels

| Level | Allowed Work | Forbidden Work | Required Docs/Evidence | Next Blocker |
|---|---|---|---|---|
| Level 0: documentation only | Planning docs, evidence mapping, templates, handoffs, and decision records. | CrabSyncV2 code, runtime assumptions beyond documented evidence, writes, RPCs, apply. | Architecture docs, migration doctrine, safety docs, current evidence docs. | Read-only feature scope and capability contracts. |
| Level 1: read-only state viewer | Read only RuntimeProbe-proven safe paths through future capability wrappers; display diagnostics; show unsupported categories. | Apply, writes, carrier writes, item sync beyond read-only display allowed by item proof. | Proven read paths for selected categories, CrabModFramework capability docs, lifecycle gates. | Deterministic convergence math and remote visibility. |
| Level 2: deterministic client-side convergence | Clients compute candidate shared state from visible replicated state; log mismatches as convergence failures. | Apply, writes, treating mismatch as write candidate, carrier writes. | Health/resource/inventory model docs for selected categories and clean read-only convergence evidence. | Transport strategy for hidden metadata if visible state is insufficient. |
| Level 3: P2P transport candidate | Carrier design review and read-only carrier planning only if carrier readiness supports it. | Carrier writes without separately approved future write-smoke; treating carrier as read/write/apply proof. | Carrier research plan, carrier readiness checklist, unsafe carrier paths, capacity/lifecycle evidence if needed. | Write-path discovery if apply is required. |
| Level 4: gated local apply prototype | Future-only local apply prototype in disposable context after write-path discovery and sandbox evidence. | Production use, broad apply, RuntimeProbe mutation, objectdump-only writes, unapproved RPC calls. | Safe write-path discovery, write ledger status, sandbox smoke evidence, explicit approval, capability gate. | Role/lifecycle coverage and repeated clean evidence. |
| Level 5: host-authoritative P2P prototype | Future-only host-authoritative prototype for categories with host/client visibility and host write/apply proof. | Joined-client apply by default, server/bridge fallback, unproven host authority, production claims. | Host/client visibility evidence, host role write/apply evidence, lifecycle policy, capability gates. | Joined-client evidence and broader lifecycle coverage. |
| Level 6: inventory item sync prototype | Future-only inventory item sync prototype after full item proof and write/apply proof. | Item sync before metadata proof, raw inventory rebuild, unknown metadata defaults, carrier-as-item-proof. | Item identity, `InventoryInfo`, `Enhancements`, duplicate semantics, joined-client replay, transport/visibility, write/apply proof. | Repeated clean inventory lifecycle evidence. |
| Level 7: stable release candidate | Future-only release-candidate review with repeated clean evidence and explicit production review. | Skipping capability gates, promoting crash-suspect evidence, hidden production writes. | Join/travel/respawn/death coverage, no crash-suspect blockers, capability-gated wrappers, production review. | Ongoing regression and safety monitoring. |

## 4. Required Architecture Docs

Architecture/doc checklist:

- [CrabSyncV2 P2P Architecture](CRABSYNCV2_P2P_ARCHITECTURE.md).
- [CrabSyncV2 v1 Migration Doctrine](CRABSYNCV2_V1_MIGRATION_DOCTRINE.md).
- [CrabSyncV2 P2P Carrier Research Plan](CRABSYNCV2_P2P_CARRIER_RESEARCH_PLAN.md).
- [P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md).
- [CrabSyncV2 Safe Write Path Discovery](CRABSYNCV2_SAFE_WRITE_PATH_DISCOVERY.md).
- [Write Path Ledger](WRITE_PATH_LEDGER.md).
- [Write Path Evidence Mapping](WRITE_PATH_EVIDENCE_MAPPING.md).
- [CrabSyncV2 Health P2P Model](CRABSYNCV2_HEALTH_P2P_MODEL.md).
- [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md).
- [CrabSyncV2 Inventory Item Proof Plan](CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md).
- [CrabModFramework Modding Guide](CRABMODFRAMEWORK_MODDING_GUIDE.md).
- [CrabModFramework API Contract](CRABMODFRAMEWORK_API_CONTRACT.md).
- [CrabModFramework Capability Model](CRABMODFRAMEWORK_CAPABILITY_MODEL.md).
- [Phase Handoff Template](PHASE_HANDOFF_TEMPLATE.md).

## 5. Required Evidence Gates

Evidence gate checklist:

- Equipment local visibility.
- Equipment remote visibility.
- Crystals local visibility.
- Crystals remote visibility.
- Slots local visibility.
- Slots remote visibility.
- Health local visibility.
- Health remote visibility.
- Inventory array shape local.
- Inventory array count local.
- Inventory item identity local.
- `InventoryInfo` scalar local.
- `Enhancements` local.
- Duplicate/same-name semantics.
- Joined-client replay of proven local phases.
- Remote inventory visibility or carrier decision.
- P2P carrier readiness if carrier is needed.
- Passive write-path observation if apply is needed.
- Sandbox write-smoke if any write/apply is needed.
- No crash-suspect unresolved blockers.

An unsupported result may satisfy a stopping condition, but it cannot satisfy a proof requirement for a feature that depends on that behavior.

## 6. P2P Carrier Readiness Gate

Carrier readiness is governed by [CrabSyncV2 P2P Carrier Research Plan](CRABSYNCV2_P2P_CARRIER_RESEARCH_PLAN.md), [P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md), and [P2P Carrier Unsafe Paths](P2P_CARRIER_UNSAFE_PATHS.md).

Carrier readiness only affects transport.

Carrier readiness does not authorize read paths.

Carrier readiness does not authorize writes.

Carrier readiness does not authorize apply.

Carrier cannot use forbidden gameplay, identity, save, currency, health, resource, equipment, slot, inventory, `InventoryInfo`, or AutoSave fields.

## 7. Health/Resource Readiness Gate

Health/resource planning is governed by [CrabSyncV2 Health P2P Model](CRABSYNCV2_HEALTH_P2P_MODEL.md) and [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md).

Health/resource read-only convergence may proceed before a carrier if visible state is enough.

Health/resource apply requires write-path proof.

Keys remain out of scope unless explicitly re-approved.

Armor remains unresolved until evidence exists.

Slot model remains unresolved until evidence exists.

## 8. Inventory Readiness Gate

Inventory planning is governed by [CrabSyncV2 Inventory Item Proof Plan](CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md).

Count metadata is not item identity.

Item identity is not metadata.

Metadata is not apply safety.

Carrier is not item read proof.

Item sync waits for item identity, `InventoryInfo`, `Enhancements`, duplicate semantics, joined-client replay, transport/visibility, and write/apply proof.

## 9. Write/Apply Readiness Gate

Write/apply planning is governed by [CrabSyncV2 Safe Write Path Discovery](CRABSYNCV2_SAFE_WRITE_PATH_DISCOVERY.md), [Write Path Ledger](WRITE_PATH_LEDGER.md), [Write Path Unsafe Paths](WRITE_PATH_UNSAFE_PATHS.md), and [Write Path Evidence Mapping](WRITE_PATH_EVIDENCE_MAPPING.md).

Function presence is not call safety.

Natural observation is not mimic permission.

RuntimeProbe must not write.

Sandbox smoke is future-only.

Production write capability requires repeated clean evidence and explicit review.

## 10. CrabModFramework Readiness Gate

Future mods should consume CrabModFramework capabilities. See [CrabModFramework Modding Guide](CRABMODFRAMEWORK_MODDING_GUIDE.md), [CrabModFramework API Contract](CRABMODFRAMEWORK_API_CONTRACT.md), and [CrabModFramework Capability Model](CRABMODFRAMEWORK_CAPABILITY_MODEL.md).

Raw UE4SS access should be wrapper-first or linted.

Capabilities have statuses.

Unsupported or unsafe status blocks behavior.

Experimental writes are unavailable until future evidence, explicit approval, and sandbox review exist.

## 11. Hard Blockers

- No server, bridge, or relay architecture copied into v2.
- No keys sync.
- No item sync before item metadata proof.
- No carrier use before carrier readiness.
- No write before write-path evidence and sandbox smoke.
- No joined-client apply before joined-client evidence.
- No raw inventory rebuild without full metadata preservation proof.
- No gameplay-critical field hijacking.
- No identity leakage.
- No unknown metadata treated as defaults.
- No crash-suspect evidence promoted as confirmed.

## 12. Unsupported Outcome Policy

Unsupported is a valid safe result.

Unsupported should block or narrow v2 scope.

Unsupported should not be worked around by guessing.

Unsupported may lead to observe-only behavior or category-disabled behavior.

Unsupported does not authorize alternate unsafe paths, broader crawling, direct writes, or carrier hijacking.

## 13. Final Readiness Decision Record

Future readiness decisions should use this table:

| Feature/category | Target readiness level | Required docs | Required evidence | Current status | Blockers | Decision | Reviewer/date | Notes |
|---|---|---|---|---|---|---|---|---|
| placeholder | Level 0 documentation only | Planning docs | Current evidence index | Not reviewed | Unknown | No runtime readiness decision | TBD | Replace before use. |
