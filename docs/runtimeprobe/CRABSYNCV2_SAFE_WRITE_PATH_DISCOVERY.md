# CrabSyncV2 Safe Write Path Discovery

This document is planning-only. It does not authorize implementation, RuntimeProbe writes, mutating RPC calls, field mutation, Crab Champions execution, local UE4SS runtime requirements, or CrabSyncV2 apply behavior.

## 1. Principle

Safe writing starts by observing vanilla behavior.

RuntimeProbe observes only. It may later document how Crab Champions naturally mutates state, but it must not call mutating functions, write fields, force synthetic values, or mutate gameplay.

CrabSyncV2 may later test candidate write/RPC paths only in explicitly gated manual sandbox phases. Official game paths are preferred over raw property writes. Raw writes are a fallback only after official paths are proven unavailable or unsafe.

Read safety is not write safety. Function presence is not call safety. Natural game behavior is evidence, not automatic permission.

Write/apply readiness remains gated by [CrabSyncV2 Readiness Checklist](CRABSYNCV2_READINESS_CHECKLIST.md). Future write-path observation, sandbox, or implementation phases should close with [Phase Handoff Template](PHASE_HANDOFF_TEMPLATE.md).

## 2. Evidence Ladder

| Status | Meaning | What it permits | What it does not permit | Next evidence needed |
|---|---|---|---|---|
| `objectdump-only` | Static symbol exists or appears in objectdump/candidates. | Planning inventory only. | Calling, writing, or assuming ownership. | Runtime-safe passive observation plan. |
| `function-presence-confirmed` | Runtime can identify a function/event/property by name without calling it. | Candidate tracking. | Invoking it or assuming arguments are safe. | Passive natural-call observation. |
| `naturally-observed-call` | Vanilla game appears to call or trigger the path naturally. | Call-flow documentation. | Mimicry, replay, or mutation. | Before/after state and authority observation. |
| `naturally-observed-before-after` | Pre/post state around natural behavior is documented. | Candidate write-path discussion. | Sandbox write-smoke or production use. | Authority, lifecycle, persistence, UI/OnRep evidence. |
| `naturally-observed-authority` | Owner/authority role appears understood from passive observation. | Role-aware planning. | Calls from other roles or contexts. | Lifecycle window and direction evidence. |
| `naturally-observed-lifecycle-window` | Safe-looking natural timing windows are documented. | Sandbox proposal preparation. | RuntimeProbe writes or broad apply. | Human review and rollback/abort plan. |
| `candidate-write-path` | Evidence suggests a path might be testable later. | Human review discussion. | Write-smoke without approval. | Explicit sandbox proposal. |
| `sandbox-write-smoke-proposed` | Manual CrabSyncV2-only test proposal exists. | Approval discussion. | Running the test without explicit approval. | User approval and disposable environment. |
| `sandbox-write-smoke-passed` | Future approved sandbox smoke passed once. | Experimental capability discussion. | Production safety claim. | Repeated stability and lifecycle evidence. |
| `limited-write-capability` | Future limited capability has evidence under strict gates. | Narrow experimental gated use planning. | Broad sync or production default. | Full readiness review. |
| `production-safe-gated` | Future production threshold after repeated evidence and rollback proof. | Production consideration only. | Skipping gates or evidence review. | Ongoing regression and safety policy. |
| `unsafe` | Path is known unsafe or too risky. | Rejection documentation. | Use as write/apply path. | Different path or explicit re-review if justified. |
| `unsupported` | Evidence cannot support the path. | Blocked status. | Apply behavior. | Alternative research. |
| `crash-suspect` | Crash or native instability may be associated. | Stop and review. | Promotion or testing. | Crash/safety analysis. |
| `diagnostic-only` | Evidence is useful only as diagnostic context. | Notes and warnings. | Readiness promotion. | Clean evidence run. |

## 3. Passive Observation Phase

For each candidate natural write path, future passive observation should collect:

- Function/event/property name.
- Object/class.
- Owner/source.
- Local role.
- Remote role, if relevant.
- Host/joined context.
- Lifecycle state.
- Arguments, with redaction/private-value policy.
- Pre-state snapshot.
- Post-state snapshot.
- OnRep/UI follow-up.
- Persistence behavior if observed naturally.
- Crash suspicion.
- Dirty evidence status.
- Notes on whether the game itself initiated it.

Passive observation must not call the function. It must not write fields, force synthetic values, or mutate gameplay.

## 4. Candidate Write Families

These are future observation families, not approved write paths.

### Equipment

- `ServerEquipInventory`
- `ServerSetWeaponDA`
- `ServerSetAbilityDA`
- `ServerSetMeleeDA`
- `OnRep_WeaponDA`
- `OnRep_AbilityDA`
- `OnRep_MeleeDA`

### Slots

- `ServerIncrementNumInventorySlots`
- `NumWeaponModSlots`
- `NumAbilityModSlots`
- `NumMeleeModSlots`
- `NumPerkSlots`
- `OnRep_Inventory`
- Inventory UI refresh behavior.

### Inventory

- Pickup flow.
- `ClientOnPickedUpPickup`.
- `OnRep_Inventory`.
- `ServerRemoveWeaponMod`.
- `ServerRemoveAbilityMod`.
- `ServerRemoveMeleeMod`.
- `ServerRemovePerk`.
- `ServerRemoveRelic`.
- `InventoryCooldowns`.
- AutoSave implications.

### Crystals

- `OnRep_Crystals`.
- Crystal scalar changes.
- Do not use crystals as a custom carrier.

### Health

- `HealthInfo.CurrentHealth`.
- `HealthInfo.CurrentMaxHealth`.
- `BaseMaxHealth`.
- `MaxHealthMultiplier`.
- Death/respawn behavior.
- Armor plate fields.
- Do not use unscoped `FindFirstOf(CrabHC)`.

### UI Refresh

- `ClientRefreshPSUI`.
- Inventory slot UI updates.
- HUD/UI observation must remain read-only unless separately approved.

### P2P Carrier

Carrier write-smoke is covered by [P2P Carrier Write-Smoke Plan](P2P_CARRIER_WRITE_SMOKE_PLAN.md). Safe write-path discovery must not override carrier readiness rules.

## 5. Mimic Policy

A future mimic may only happen if:

- Natural game path was observed.
- Arguments are understood.
- Before/after state is understood.
- Authority/ownership is understood.
- Role direction is understood.
- Lifecycle constraints are known.
- Persistence side effects are understood.
- UI/OnRep follow-up is understood.
- Rollback/abort rule exists.
- The write is behind explicit capability gates.
- The user explicitly approves sandbox testing.
- The test is not in RuntimeProbe default campaign.

## 6. Sandbox Write-Smoke Policy

Future write-smoke is:

- Not RuntimeProbe.
- Separate CrabSyncV2 experimental profile.
- Manual-only.
- Disposable run.
- Explicit config flag.
- One write path at a time.
- One candidate state change at a time.
- Tiny/no-op or naturally equivalent change preferred.
- Before/after recorded.
- Not tested during join, travel, respawn, or loading.

Stop after any crash, unknown side effect, dirty state, or unexpected persistence.

Passing smoke creates only an experimental candidate, not production safety.

## 7. Write Path Ledger Format

Future write-path ledgers should use this schema:

| Path ID | Category | Object/Class | Function/Property/Event | Observed naturally? | Args understood? | Authority | Direction | Lifecycle window | Side effects | Persistence | UI/OnRep | Risk | Current status | Evidence session | Next evidence needed | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| none | none | none | none | no | no | unknown | unknown | unknown | unknown | unknown | unknown | unknown | unsupported | none | Passive observation evidence. | No write path is safe today. |

## 8. Explicitly Unsafe Until Proven

Unsafe until separately proven:

- Direct live inventory array rebuilds.
- Raw writes to `InventoryInfo`.
- Raw writes to `Enhancements`.
- Raw writes to `Level`/`AccumulatedBuff`.
- Raw writes to keys, unlocks, or save data.
- Unscoped `CrabHC` writes.
- Mutating RPC calls during join, travel, respawn, or loading.
- Writes from unknown role.
- Writes without PlayerState generation stability.
- Writes without before/after evidence.
- Writes that rely on stale remote state.
- Writes that modify identity, matchmaking, display name, `UniqueId`, or save metadata.
- Writes that use gameplay-critical fields as custom payload carriers.

## 9. Official Path Vs Raw Write Decision Tree

1. Prefer naturally observed official function/RPC/event paths.
2. If an official path exists but is untested, status remains `objectdump-only` or `function-presence-confirmed`.
3. If an official path is naturally observed, collect before/after state and authority data.
4. If the official path cannot be proven safe, raw write remains blocked.
5. Raw write can only become a candidate after metadata preservation, UI/OnRep behavior, persistence behavior, rollback, and lifecycle behavior are documented.
6. No destructive array rebuilds without full metadata preservation proof.

## 10. Relationship To P2P Design

P2P transport does not remove write safety requirements. Deterministic read-only convergence should be preferred before apply.

Carrier readiness does not authorize apply. Health/resource visibility does not authorize mutation. Item identity proof does not authorize inventory rebuild.

Write safety is a separate gate from read safety and transport safety.

## 11. Relationship To RuntimeProbe

RuntimeProbe remains read-only.

RuntimeProbe may later observe natural game calls passively. RuntimeProbe must not call mutating RPCs and must not write fields.

Any future write-smoke belongs to a CrabSyncV2-only sandbox.

## 12. Future Output Docs

Future planning/status outputs may include:

- `docs/WRITE_PATH_LEDGER.md`: candidate write paths, evidence ladder status, authority, lifecycle, side effects, and next evidence. Future status output, not current proof.
- `docs/WRITE_PATH_UNSAFE_PATHS.md`: rejected write/apply paths and why they are unsafe, unsupported, crash-suspect, destructive, identity-risky, save-risky, or stale. Future status output, not current proof.
- `docs/WRITE_PATH_OBSERVED_NATURAL_CALLS.md`: passive natural call observations with redacted arguments and before/after summaries. Future status output, not call approval.
- `docs/WRITE_PATH_SANDBOX_SMOKE_PLAN.md`: future CrabSyncV2-only sandbox smoke proposals after explicit approval criteria are met. Future plan, not current authorization.

Template/status docs now exist for [Write Path Ledger](WRITE_PATH_LEDGER.md), [Write Path Unsafe Paths](WRITE_PATH_UNSAFE_PATHS.md), [Write Path Observed Natural Calls](WRITE_PATH_OBSERVED_NATURAL_CALLS.md), and [Write Path Sandbox Smoke Plan](WRITE_PATH_SANDBOX_SMOKE_PLAN.md). These docs should not be filled as proof until passive observation and sandbox evidence exist.

[Write Path Evidence Mapping](WRITE_PATH_EVIDENCE_MAPPING.md) defines how future passive evidence rows should map into those docs. It is a mapping specification only and does not implement collectors, imports, write probes, RPC calls, or sandbox smoke.
