# P2P Carrier Safety Gates

This document defines future safety gate names for P2P carrier research planning. These gates are planning names only and are not implemented by this task.

No gate described here authorizes RuntimeProbe writes, mutating RPCs, gameplay mutation, Crab Champions execution, local UE4SS runtime requirements, or CrabSyncV2 implementation.

## 1. Purpose

The purpose of this document is to define default safety posture, proposed future gate scopes, forbidden gate combinations, required safety markers, crash/dirty evidence policy, and human approval rules for carrier research.

## 2. Proposed Future Gates

| Gate | Default value | Scope | Allowed evidence | Explicitly forbidden actions | Related phase contract | Expected safety markers |
|---|---|---|---|---|---|---|
| `allowP2PCarrierDiscoveryProbes` | `false` | Scoped read-only candidate discovery. | Candidate class/name/type/owner summaries, redacted identity, rejection markers. | Writes, RPCs, mutation, broad object crawling, inventory traversal, `InventoryInfo`, `Enhancements`. | `p2p-carrier-discovery-read` | `noWrites`, `noRpcs`, `noMutation`, `rawIdentityEvidence=false`, `noDataAssetMutation`, `noInventoryInfo`, `noEnhancements`. |
| `allowP2PCarrierVisibilityWatchProbes` | `false` | Read-only visibility observation for already scoped candidates. | Visibility direction, role/context tags, natural value-change presence. | Synthetic payloads, writes, RPCs, mutation, forced gameplay changes. | `p2p-carrier-visibility-watch` | `noWrites`, `noRpcs`, `noMutation`, `passiveOnly`. |
| `allowP2PCarrierCapacityReadProbes` | `false` | Read-only capacity/cadence observation from natural values. | Value kind, natural observed length, cadence, maximum natural observed size. | Synthetic payload writes, increasing value size, forced updates, mutation, RPCs. | `p2p-carrier-capacity-read` | `noWrites`, `noRpcs`, `noMutation`, `passiveOnly`. |
| `allowP2PCarrierLifecycleWatchProbes` | `false` | Read-only lifecycle behavior watch for candidates. | Presence/absence, stale/reset behavior, role/lifecycle tags. | Writes, RPCs, forced transitions beyond normal manual play. | `p2p-carrier-lifecycle-watch` | `noWrites`, `noRpcs`, `noMutation`, `passiveOnly`. |
| `allowP2PCarrierRawIdentityEvidence` | `false` | Exceptional identity evidence review only. | Redacted/fingerprinted identity by default; raw identity only with explicit approval. | Default raw names/IDs, identity carrier approval, matchmaking mutation. | Discovery/visibility phases when identity risk is being reviewed. | `rawIdentityEvidence=false` unless explicitly approved, `noWrites`, `noRpcs`. |
| `allowP2PCarrierWriteSmoke` | Not in RuntimeProbe default config | Future CrabSyncV2-only sandbox, not RuntimeProbe. | Future tiny sentinel result only after explicit approval. | RuntimeProbe default mutation, production enablement, broad writes, RPC abuse. | `p2p-carrier-write-smoke` boundary only. | Sandbox-specific markers, explicit approval, rollback/abort criteria. |
| `allowP2PCarrierUnsafeCandidateReview` | `false` | Docs/import review of rejected candidates. | Rejection classification and unsafe-path updates. | Promoting rejected candidates to approved carriers automatically. | `p2p-carrier-rejection-classification` | Review-only marker, `noWrites`, `noRpcs`. |

## 3. Default Safety Posture

- All P2P carrier research gates are false by default.
- Write-smoke gate does not belong to RuntimeProbe default config.
- No carrier phase enables writes or RPCs.
- Raw identity evidence remains false by default.
- Broad deep traversal remains forbidden.
- Unsupported is a valid safe result.

## 4. Forbidden Gate Combinations

Forbidden combinations:

- Carrier discovery plus writes/RPCs.
- Carrier visibility watch plus writes/RPCs.
- Carrier capacity read plus synthetic payload writes.
- Carrier research plus `InventoryInfo`/`Enhancements` unless a separate explicit phase exists.
- Carrier research plus raw identity evidence unless explicitly approved.
- Carrier write-smoke inside RuntimeProbe default campaign.

If any forbidden combination appears in a future manifest, evidence from that run must not promote a carrier candidate.

## 5. Required Safety Markers By Phase

| Phase | Required safety markers | Forbidden gates | Outcome if marker missing |
|---|---|---|---|
| `p2p-carrier-discovery-read` | `noWrites=true`, `noRpcs=true`, `noMutation=true`, `rawIdentityEvidence=false`, `noDataAssetMutation=true`, `noInventoryInfo=true`, `noEnhancements=true` | write/RPC/raw identity/deep inventory gates | Mark evidence dirty or unsupported; do not promote candidate. |
| `p2p-carrier-visibility-watch` | `noWrites=true`, `noRpcs=true`, `noMutation=true`, `passiveOnly=true` | write/RPC/synthetic payload gates | Mark visibility inconclusive; do not confirm visibility. |
| `p2p-carrier-capacity-read` | `noWrites=true`, `noRpcs=true`, `noMutation=true`, `passiveOnly=true` | synthetic payload/write/RPC gates | Mark capacity inconclusive; do not set `capacity-observed`. |
| `p2p-carrier-lifecycle-watch` | `noWrites=true`, `noRpcs=true`, `noMutation=true`, `passiveOnly=true` | write/RPC/forced transition gates | Mark lifecycle inconclusive or stale-risk; do not promote. |
| `p2p-carrier-rejection-classification` | `reviewOnly=true`, `noWrites=true`, `noRpcs=true` | write/RPC/auto-approval gates | Keep rejection unresolved; require human review. |
| `p2p-carrier-summary-import` | `docsOnly=true`, `preserveEvidenceMeaning=true`, `noAutoWriteSmokePromotion=true` | evidence rewrite/auto approval gates | Refuse import or mark output diagnostic-only. |

## 6. Crash/Dirty Evidence Policy

- `crash_suspect` result blocks promotion.
- Dirty evidence cannot classify a carrier as confirmed.
- Diagnostic-only imports must stay marked as diagnostic-only.
- Unsupported is a valid safe result.
- Missing safety markers, raw private identity leaks, or forbidden gate combinations keep evidence out of confirmation paths.

## 7. Human Approval Rules

Future write-smoke requires:

- Explicit user approval.
- Disposable test run.
- One candidate at a time.
- No join/travel/respawn/loading during the smoke.
- Abort criteria documented.
- No production enablement from one smoke pass.

Even after approval, write-smoke remains a CrabSyncV2-only sandbox activity and never becomes RuntimeProbe default behavior.
