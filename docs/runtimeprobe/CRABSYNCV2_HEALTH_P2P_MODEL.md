# CrabSyncV2 Health P2P Model

This document is planning-only. It does not authorize RuntimeProbe writes, CrabSyncV2 implementation, health apply, mutating RPCs, or local UE4SS runtime work.

## 1. Purpose

Define the future P2P health model for CrabSyncV2 from currently documented RuntimeProbe visibility.

This is architecture and read-convergence planning only. It describes how future clients could observe, normalize, and compare health inputs before any apply behavior exists.

This document does not authorize health writes or health apply. It also does not prove that health apply is safe.

Pooled/shared health is a CrabSyncV2 design concept. It is not a vanilla RuntimeProbe fact and must not be described as proven runtime behavior.

## 2. Current Evidence

The current player health source starts from:

`CrabPC -> PlayerState -> CrabPS -> HealthInfo`

Do not use unscoped `FindFirstOf(CrabHC)` for player health. Existing evidence has observed an unscoped non-player `CrabHC` candidate, so unscoped `CrabHC` is unsafe and ambiguous for player health decisions.

Remote `HealthInfo.CurrentHealth` and `HealthInfo.CurrentMaxHealth` visibility appears available through visible PlayerStates. `BaseMaxHealth` and `MaxHealthMultiplier` also have read visibility evidence.

The evidence supports P2P health derivation as plausible. It does not support health mutation, health apply, pooled health behavior, or any write path.

## 3. What Is Proven

- Read visibility of health scalars is documented for PlayerState-scoped paths.
- The player-state-scoped source path is `CrabPC -> PlayerState -> CrabPS -> HealthInfo`.
- Remote PlayerState health scalar visibility is plausible and partially supported by existing resource visibility docs.
- Unscoped `CrabHC` is unsafe and ambiguous for player health.

## 4. What Is Not Proven

- Pooled/shared health behavior.
- Health apply safety.
- Armor policy.
- Death/respawn behavior.
- UI consistency after health changes.
- Max-health contribution math.
- Host-authoritative health writes.
- Joined-client health apply.
- Player-owned `CrabHC` fallback.
- `HealthInfo` as a custom carrier. It must remain forbidden as a `CrabSyncBlock` payload path.

## 5. Proposed Read-Only Convergence Model

Each client builds a visible player health table from evidence-approved PlayerState-scoped reads.

Each row includes:

- Player fingerprint.
- Role/context if known.
- `CurrentHealth`.
- `CurrentMaxHealth`.
- `BaseMaxHealth`.
- `MaxHealthMultiplier`.
- Source path.
- Timestamp/generation.
- Visibility class.

All numeric values are range-clamped and finite-checked before entering convergence math. Invalid, missing, stale, or out-of-generation rows are marked unsupported and excluded by policy rather than coerced into apply candidates.

Clients compute candidate team health and candidate team max health deterministically from the same visible rows. The first goal is comparison: each client should be able to explain why it derived the same or different read-only result.

The initial phase does not apply anything. Discrepancies are recorded as convergence failures, not write candidates.

## 6. Possible Health Policies

### Observe-Only

Required evidence: stable PlayerState-scoped health reads by role, lifecycle generation, and visibility class.

Risk: low, provided reads remain scoped and no lifecycle-stale rows are trusted.

Readiness: ready only as a planning target for read-only diagnostics. It does not authorize apply.

### Sum Current/Max

Required evidence: all relevant players are visible, current/max values are stable enough for deterministic client-side math, and lifecycle exclusions are documented.

Risk: high. Summing can create a v2 pool that differs from vanilla behavior, especially during death, respawn, join, leave, or max-health changes.

Readiness: not ready. It is a candidate convergence policy only.

### Max Current/Max

Required evidence: proof that taking the maximum visible current/max pair is stable and intentional for the gameplay design.

Risk: medium to high. It may hide damage taken by other players and can diverge from pooled-health expectations.

Readiness: not ready. It may be useful as a display or diagnostic policy, but not as apply behavior.

### Host-Authoritative Pooled Health

Required evidence: host can observe all required PlayerState health inputs, joined clients can detect host generation safely, lifecycle rules are documented, and future write-path evidence exists.

Risk: critical. This introduces authority and apply semantics that are not proven by RuntimeProbe visibility.

Readiness: not ready. It requires future write-path discovery, sandbox review, explicit approval, and CrabSyncV2-only implementation gates.

### Local-Only Health, Remote Display Only

Required evidence: stable local health reads plus remote health display rows with clear visibility classes.

Risk: low to medium. It avoids apply but could confuse users if display values appear authoritative.

Readiness: plausible as a read-only UI/diagnostic concept after convergence proof, not as health sync.

### Shared Max Health But Local Current Health

Required evidence: deterministic max-health contribution math, lifecycle exclusions, and evidence that current health remains local-only by policy.

Risk: high. Max-health changes can still affect survivability and UI, and apply remains unproven.

Readiness: not ready. It is a design option for later discussion only.

### Downscale/Normalize Policy After Player Leave/Death

Required evidence: documented player leave, disconnect, death, respawn, and stale-row generation behavior.

Risk: critical. Incorrect normalization can kill players, heal players, or desync UI.

Readiness: not ready. It depends on lifecycle research and future apply gates.

## 7. Death, Respawn, Join, Travel

The following lifecycle concerns are unresolved and must suspend convergence when detected:

- Health during loading.
- Terminal `0/0`.
- Death protection windows.
- Respawn reset behavior.
- Stale remote health rows.
- Player leave/disconnect.
- Joining mid-run.
- Generation reset requirements.
- Any transition where PlayerState identity, role, or health source stability is uncertain.

When suspended, the model records unsupported or stale state. It must not convert lifecycle uncertainty into an apply plan.

## 8. Armor Policy

Armor plates are unresolved.

Do not sync armor until evidence exists. Future evidence should inspect armor fields only through safe PlayerState-scoped paths if available.

Armor apply is blocked until separate write-path evidence exists, a policy is documented, and explicit approval is given.

## 9. Apply Gate

Health apply requires all of the following:

- Read-only convergence proven clean.
- Lifecycle policy documented.
- Death/respawn behavior documented.
- Armor decision documented.
- Write-path discovery evidence exists.
- Sandbox write-smoke proposal reviewed.
- Explicit user approval.
- No crash-suspect blockers.
- Capability gate in CrabModFramework/CrabSyncV2.
- Not RuntimeProbe.

Missing any item keeps health apply blocked.

## 10. Interaction With P2P Carrier

Health does not need a carrier if visible PlayerState data is enough.

`HealthInfo` and health scalar fields are forbidden as custom `CrabSyncBlock` carriers. Health visibility can support derivation only; it must not be used as a payload channel.

Carrier readiness does not authorize health apply. Transport, read/convergence, and write/apply gates remain separate.

A future carrier may only help transport hidden metadata if later proven safe and unrelated to health fields.

## 11. Open Questions And Next Phases

- `p2p-health-convergence-read`: verify stable PlayerState-scoped health rows and deterministic read-only math.
- `multiplayer-health-lifecycle-watch`: observe health visibility across join, travel, death, respawn, leave, and disconnect without apply.
- `armor-visibility-read`: inspect armor visibility only through safe PlayerState-scoped paths if evidence supports them.
- `health-write-path-observation`: passive only; observe natural game behavior without calling functions or mutating fields.
- `health-apply-sandbox`: future CrabSyncV2-only phase, not RuntimeProbe, requiring explicit approval before any sandbox proposal.
