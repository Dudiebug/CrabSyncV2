# P2P Carrier Readiness Checklist

This is a future decision checklist for CrabSyncV2 P2P carrier research. It does not prove a carrier exists today, does not authorize writes or write-smoke, and does not implement RuntimeProbe collectors, gates, probes, imports, generated docs, or CrabSyncV2 code.

This checklist is carrier-specific. It feeds the master [CrabSyncV2 Readiness Checklist](CRABSYNCV2_READINESS_CHECKLIST.md), but it does not replace read, inventory, write/apply, CrabModFramework, or production readiness gates.

## 1. Purpose

This checklist defines how future carrier evidence will be evaluated before any CrabSyncV2 design decision depends on a carrier.

Carrier readiness is only one part of CrabSyncV2 readiness. Transport readiness does not prove inventory read correctness, item metadata correctness, duplicate semantics, write/apply safety, or joined-client apply behavior.

RuntimeProbe remains read-only. Read evidence never equals write evidence.

Carrier readiness does not satisfy write/apply readiness; future write behavior must separately follow [CrabSyncV2 Safe Write Path Discovery](CRABSYNCV2_SAFE_WRITE_PATH_DISCOVERY.md).

Health, equipment, crystals, and slots may proceed with read-only convergence planning without a carrier if visible replicated state is sufficient. That path is category derivation, not transport readiness and not apply approval.

Use [Write Path Ledger](WRITE_PATH_LEDGER.md), [Write Path Unsafe Paths](WRITE_PATH_UNSAFE_PATHS.md), [Write Path Observed Natural Calls](WRITE_PATH_OBSERVED_NATURAL_CALLS.md), and [Write Path Sandbox Smoke Plan](WRITE_PATH_SANDBOX_SMOKE_PLAN.md) to keep carrier transport readiness separate from write/apply readiness.

## 2. Readiness Levels

| Level | Name | Meaning | What it can unblock |
|---|---|---|---|
| Level 0 | no carrier evidence | No candidates found or no carrier research evidence exists. | No P2P payload plan can depend on a carrier. |
| Level 1 | read-discovered candidate | Candidate appears in read-only discovery, but no visibility proof exists. | Candidate tracking only; cannot unblock `CrabSyncBlock` design. |
| Level 2 | visibility-confirmed candidate | Candidate is visible across a useful direction, but capacity/cadence/lifecycle proof is still missing. | Architecture discussion only. |
| Level 3 | capacity/lifecycle-observed candidate | Visibility, capacity, cadence, lifecycle behavior are documented and candidate is absent from unsafe carrier paths. | May become a human-reviewed write-smoke candidate; still not production transport. |
| Level 4 | write-smoke candidate, future only | Requires human review, explicit user approval, and CrabSyncV2-only sandbox. Not RuntimeProbe and not automatic. | A request for manual sandbox testing only. |
| Level 5 | experimental carrier capability, future only | Only after write-smoke passes; still feature-gated. | Experimental capability discussion only; not production safe. |
| Level 6 | production carrier, future only | Requires repeated stability evidence, lifecycle/join/travel/respawn coverage, no save/identity/gameplay corruption, and documented rollback/clear behavior. | Future production transport consideration only. |

## 3. Decision Categories

| Outcome | Meaning | Required evidence | What it permits | What it does not permit | Next recommended research step |
|---|---|---|---|---|---|
| `blocked_no_candidate` | No candidate exists in carrier status docs. | Empty/no candidate rows. | Record Level 0. | Carrier-dependent design. | Run future read-only discovery. |
| `blocked_only_unsafe_candidates` | All candidates are rejected or forbidden. | Unsafe-path entries or rejection rows. | Document rejection. | Carrier use or write-smoke. | Search different non-gameplay candidate classes. |
| `blocked_visibility_missing` | Candidate is read-discovered but not visible in useful topology. | Candidate row without visibility matrix proof. | Candidate tracking. | `CrabSyncBlock` design dependency. | Run visibility watch. |
| `blocked_capacity_unknown` | Visibility exists but capacity/cadence is unknown. | Visibility rows but no capacity observation. | Architecture discussion. | Write-smoke proposal. | Run capacity read from natural values only. |
| `blocked_lifecycle_unstable` | Candidate is stale or unstable across lifecycle. | Lifecycle rows with stale/unstable result. | Rejection or unresolved status. | Carrier dependency. | Add unsafe-path entry or more lifecycle watch if safe. |
| `blocked_identity_or_save_risk` | Identity or save risk is present or unresolved. | Identity/save sensitivity markers. | Rejection or human review. | Carrier use, write-smoke, production planning. | Reject or obtain explicit review. |
| `blocked_gameplay_authority` | Candidate affects gameplay authority. | Gameplay-authority marker or known forbidden class. | Unsafe carrier classification. | Carrier use. | Use for read-only derivation only if separately safe. |
| `architecture_read_only_only` | Candidate/path can support display or diagnostics only. | Clean read evidence without carrier viability. | Read-only status/display planning. | Transport, writes, apply. | Continue non-carrier P2P derivation research. |
| `architecture_p2p_derivation_only` | Visible state supports deterministic local math but not payload transport. | Clean visible-state rows and carrier rejection. | P2P derivation design. | `CrabSyncBlock` payload transport. | Prove category-specific convergence. |
| `candidate_for_write_smoke_review` | Level 3 candidate may be reviewed for future sandbox request. | Visibility, capacity, lifecycle, owner/source, clean evidence, absent from unsafe paths. | Human review discussion. | Automatic write-smoke or production transport. | Prepare write-smoke proposal only after approval. |
| `experimental_only_after_sandbox` | A future approved sandbox smoke has passed. | Future sandbox evidence, not RuntimeProbe. | Experimental gated capability discussion. | Production transport. | Repeat stability/lifecycle testing. |
| `production_ready_future_only` | Production carrier threshold, future only. | Repeated stability, lifecycle coverage, no corruption, clear/rollback proof. | Future production consideration. | Current implementation. | Full CrabSyncV2 readiness review. |

## 4. Minimum Evidence Before Any `CrabSyncBlock` Design Can Depend On A Carrier

All must be true:

- Candidate exists in [P2P Carrier Candidates](P2P_CARRIER_CANDIDATES.md).
- Candidate is not listed as unsafe in [P2P Carrier Unsafe Paths](P2P_CARRIER_UNSAFE_PATHS.md).
- Candidate has visibility rows in [P2P Carrier Visibility Matrix](P2P_CARRIER_VISIBILITY_MATRIX.md).
- Direction is useful for the intended topology.
- Owner/source is understood.
- Lifecycle behavior is documented.
- Raw/private identity risk is controlled.
- Save/persistence risk is understood.
- Gameplay authority risk is rejected or cleared.
- Capacity is sufficient for at least a minimal block.
- Update cadence is sufficient.
- Clear/reset behavior is understood.
- `crash_suspect` is false.
- Evidence is clean, not diagnostic-only.

## 5. Minimum Evidence Before Write-Smoke Can Even Be Proposed

All must be true before a future proposal:

- All Level 3 criteria are met.
- Explicit user approval is documented.
- Candidate is absent from unsafe paths.
- No gameplay-critical use.
- No identity or matchmaking use.
- No save-persistent harmful behavior.
- Clear/reset theory is documented.
- Manual disposable test environment is documented.
- One candidate only.
- One sentinel only.
- Abort criteria are documented.
- CrabSyncV2-only sandbox plan exists.
- RuntimeProbe default campaign remains read-only.

These prerequisites do not authorize the write-smoke. They only define the minimum bar before asking for approval.

## 6. Carrier Rejection Rules

A candidate is rejected if any apply:

- Gameplay-authoritative.
- Currency/progression.
- Identity/matchmaking.
- Save-persistent with unknown clear/reset.
- Health/gameplay critical as custom carrier.
- Equipment authority as custom carrier.
- Inventory authority as custom carrier.
- UI/user-visible deception risk.
- Local-only.
- Unstable lifecycle.
- Requires mutating RPC.
- Unknown ownership that cannot be resolved.
- Raw private identity required.
- Crash-suspect evidence.

Rejected-as-carrier status does not erase safe read evidence. A path may remain useful for read-only P2P derivation while still forbidden for `CrabSyncBlock` transport.

## 7. Interaction With P2P Categories

**Health:** can proceed with read-only convergence if visible `PlayerState` data is enough. A carrier is not required unless hidden metadata is needed. Carrier readiness does not authorize health apply.

**Equipment:** can proceed with read-only visibility if DA state is visible. A carrier is not required for observation. Write/apply still needs write-path discovery.

**Crystals:** can proceed with read-only convergence if visible. Never use `Crystals` itself as a carrier.

**Slots:** can proceed with read-only convergence if visible. Slot model remains unresolved. Never use `Num*Slots` as a carrier.

**Inventory items:** a carrier may be needed if remote item metadata is not visible. A carrier does not replace local item identity, `InventoryInfo`, `Enhancements`, duplicate semantics, or apply proof. A carrier only solves transport.

Item sync also requires [CrabSyncV2 Inventory Item Proof Plan](CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md). Carrier readiness cannot promote inventory proof rungs or convert unknown metadata into observed metadata.

## 8. Carrier Readiness Does Not Unblock These By Itself

- Inventory item sync.
- `InventoryInfo` reads.
- `Enhancements` reads.
- Live apply.
- Write/RPC execution.
- Joined-client apply.
- Health pooling apply.
- Slot mutation.
- Equipment mutation.
- Save-affecting behavior.

## 9. Evidence Cleanliness Rules

- Clean evidence can support status promotion.
- Unsupported evidence can support rejection or blocked status.
- Crash-suspect evidence blocks promotion.
- Diagnostic-only evidence cannot confirm readiness.
- Dirty working tree or stale generated docs must be reported.
- Conflicting evidence keeps candidate unresolved.

## 10. Human Review Gate

Human review is required for:

- Promoting Level 3 to Level 4.
- Proposing any write-smoke.
- Reclassifying a forbidden candidate.
- Using a user-visible field.
- Using any field with save/persistence uncertainty.
- Using host-authoritative-only paths as v2 transport.
- Changing the no-server/no-bridge v2 assumption.

## 11. Example Readiness Decisions

These are fictional non-evidence examples. They do not prove a carrier exists.

| Example | Readiness decision | Notes |
|---|---|---|
| Cosmetic status field reaches Level 2 but lacks capacity. | `blocked_capacity_unknown` | Architecture discussion only; no write-smoke proposal. |
| Local-only UI field is discovered. | `rejected-local-only` | Local-only paths cannot support P2P transport. |
| `HealthInfo` is visible. | useful for P2P derivation, rejected as custom carrier | Health visibility can support read-only convergence planning but not payload transport. |
| PlayerName-like field is discovered. | `rejected-identity-risk` | Identity and user-visible naming fields are not carriers. |
| Non-authoritative transient player tag hypothetically reaches Level 3. | `candidate_for_write_smoke_review` | Still not approved; requires human review and explicit approval. |

## 12. Relationship To Existing Docs

This checklist depends on:

- [CrabSyncV2 Health P2P Model](CRABSYNCV2_HEALTH_P2P_MODEL.md).
- [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md).
- [CrabSyncV2 Inventory Item Proof Plan](CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md).
- [CrabSyncV2 P2P Carrier Research Plan](CRABSYNCV2_P2P_CARRIER_RESEARCH_PLAN.md).
- [P2P Carrier Candidates](P2P_CARRIER_CANDIDATES.md).
- [P2P Carrier Visibility Matrix](P2P_CARRIER_VISIBILITY_MATRIX.md).
- [P2P Carrier Unsafe Paths](P2P_CARRIER_UNSAFE_PATHS.md).
- [P2P Carrier Write-Smoke Plan](P2P_CARRIER_WRITE_SMOKE_PLAN.md).
- [P2P Carrier Evidence Mapping](P2P_CARRIER_EVIDENCE_MAPPING.md).
- [P2P Carrier Discovery Phase Contracts](P2P_CARRIER_DISCOVERY_PHASE_CONTRACTS.md).
- [P2P Carrier Safety Gates](P2P_CARRIER_SAFETY_GATES.md).

Use this checklist as the carrier-specific decision layer after future evidence import. It is not the full CrabSyncV2 readiness checklist.
