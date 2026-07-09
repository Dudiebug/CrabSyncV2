# CrabSyncV2 P2P Architecture (Planning)

CrabSyncV2 is a future architecture target. This document is planning-only and does not authorize implementation, RuntimeProbe writes, or mutating RPC usage.

## Design Premise

CrabSyncV2 is **P2P/game-native first**:

- No external relay/server as a default transport model.
- No PowerShell bridge process.
- No push/recv JSON IPC transport.
- No room password or relay dashboard control plane.

The intended model is to derive what can be synchronized from the game's own replicated runtime state first, then add narrowly scoped extensions only when evidence proves they are safe.

CrabSyncV2 should consume future [CrabModFramework API Contract](CRABMODFRAMEWORK_API_CONTRACT.md) wrappers and [CrabModFramework Capability Model](CRABMODFRAMEWORK_CAPABILITY_MODEL.md) statuses rather than direct raw UE4SS calls where possible.

Before any future CrabSyncV2 behavior starts, use [CrabSyncV2 Readiness Checklist](CRABSYNCV2_READINESS_CHECKLIST.md). Close future docs, evidence, carrier, write-path, sandbox, or implementation phases with [Phase Handoff Template](PHASE_HANDOFF_TEMPLATE.md).

## Why CrabInvSync v1 Transport Is Not Copied

CrabInvSync v1 proved useful as a prototype, but its transport model is intentionally not carried forward as the CrabSyncV2 baseline.

For the detailed v1-to-v2 decision record, see [CrabSyncV2 v1 Migration Doctrine](CRABSYNCV2_V1_MIGRATION_DOCTRINE.md).

v1 bridge/server architecture introduced:

- Added end-to-end latency beyond game-native replication.
- External failure modes (bridge/replay/relay availability and stale process state).
- Stale room or transport state risks during join/travel/reconnect transitions.
- A non-game-native authority layer that could diverge from in-session game truth.

## What v1 Still Contributes (Archival Prototype Lessons)

CrabInvSync v1 remains an **archival/prototype reference** for safety and modeling lessons:

- Lifecycle gates and transition-aware safety stops.
- Metadata-aware item model expectations.
- Joined-client caution and role-aware behavior.
- Range clamping discipline.
- Diagnostic logging for reads/plans/skips.
- Stale-state protection and generation checks.

These lessons inform v2 safety posture, but do not re-approve the v1 transport stack.

## Planned P2P Sync Model

CrabSyncV2 planning currently targets this progression:

1. Derive state from visible replicated `PlayerState` surfaces when possible.
2. Use deterministic local client math for categories where every client can observe sufficient shared state.
3. Consider host-authoritative behavior only where evidence shows host visibility is sufficient and safer than symmetric peer convergence.
4. Consider a custom `CrabSyncBlock` carrier only through [CrabSyncV2 P2P Carrier Research Plan](CRABSYNCV2_P2P_CARRIER_RESEARCH_PLAN.md), and only if future evidence proves a safe replicated carrier path.

## Category Feasibility (Current Evidence-Aware Planning)

- **Health**: likely P2P candidate based on remote `HealthInfo` visibility evidence; apply/pooling behavior remains design-gated by [CrabSyncV2 Health P2P Model](CRABSYNCV2_HEALTH_P2P_MODEL.md).
- **Equipment**: likely P2P candidate based on remote equipment DA visibility evidence; apply remains blocked by [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md).
- **Crystals**: likely P2P candidate based on remote `Crystals` visibility evidence; keys are excluded and crystal apply remains blocked by [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md).
- **Slots**: plausible candidate; slot model and policy remain unresolved in [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md).
- **Inventory items**: blocked until the proof ladder in [CrabSyncV2 Inventory Item Proof Plan](CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md) proves item identity, metadata, duplicate semantics, joined-client safety, and remote visibility or a reviewed carrier decision.

This feasibility list is a planning status snapshot, not proof of end-to-end sync safety.

## Explicit Non-Goals

- No external relay fallback unless explicitly re-approved in future planning.
- No custom transport tunneled through gameplay-critical values, including:
  - `Crystals`
  - keys
  - `HealthInfo`
  - slot counts
  - equipment DA fields
  - `PlayerName`
  - `UniqueId`
  - inventory arrays
  - AutoSave fields
- No mutation during RuntimeProbe evidence collection.

## Safety Boundaries

- RuntimeProbe remains read-only evidence collection.
- CrabModFramework remains the future safe access layer for any eventual implementation.
- CrabSyncV2 does not exist yet; this document defines architecture intent, not runtime behavior proof.
- No `CrabSyncBlock` carrier exists today; carrier work is research-only until proven by the carrier plan.
