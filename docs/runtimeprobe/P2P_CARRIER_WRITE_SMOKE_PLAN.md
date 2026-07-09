# P2P Carrier Write-Smoke Plan

This is a future-only manual CrabSyncV2 sandbox plan template. It is not authorized today, it is not a RuntimeProbe phase, and it does not approve any implementation, write probe, mutation, RPC call, or synthetic payload.

Any future write-smoke test requires explicit user approval before it exists as code.

Future checklist proposals should follow [P2P Carrier Evidence Mapping](P2P_CARRIER_EVIDENCE_MAPPING.md). Mapping evidence into this template does not approve write-smoke.

Future approval requests must also satisfy [P2P Carrier Safety Gates](P2P_CARRIER_SAFETY_GATES.md). That safety-gate document does not implement or authorize write-smoke.

[P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md) is a prerequisite for any future write-smoke proposal. It does not approve write-smoke by itself.

Carrier write-smoke is a specific case of the broader [CrabSyncV2 Safe Write Path Discovery](CRABSYNCV2_SAFE_WRITE_PATH_DISCOVERY.md) sandbox doctrine, while still controlled by stricter carrier readiness rules.

[Write Path Sandbox Smoke Plan](WRITE_PATH_SANDBOX_SMOKE_PLAN.md) defines the general write-smoke template; this carrier-specific plan remains stricter and does not authorize any carrier write today.

## Minimum Prerequisites

Before a write-smoke can even be considered:

- Candidate exists in [P2P Carrier Candidates](P2P_CARRIER_CANDIDATES.md).
- Candidate has `visibility-confirmed` status.
- Candidate is not listed as forbidden or rejected in [P2P Carrier Unsafe Paths](P2P_CARRIER_UNSAFE_PATHS.md).
- Lifecycle behavior is documented.
- Capacity and cadence are documented.
- Clear/reset behavior is understood.
- Manual disposable test environment is defined.
- Rollback/abort criteria are defined.

These prerequisites do not authorize the test. They only define the minimum bar for requesting separate approval.

## Future Write-Smoke Sentinel

If explicitly approved in the future, the only planned sentinel is:

```text
CS2_SMOKE_1
```

The sentinel must stay tiny, non-production, and scoped to a disposable CrabSyncV2-only sandbox.

## Write-Smoke Success Criteria

A future approved write-smoke would need all of the following:

- Local write succeeds.
- Remote observation succeeds.
- Value clears or resets.
- No crash.
- No save corruption or dirty save risk.
- No identity corruption.
- No gameplay corruption.
- No user-visible misleading state.

Passing write-smoke only creates an experimental capability candidate. It does not create production-safe transport.

## Abort Criteria

Abort immediately on:

- Crash.
- Dirty save risk.
- Identity/name changed.
- Gameplay value changed.
- Value persists unexpectedly.
- Remote mismatch.
- Lifecycle instability.

Any abort result should keep the candidate out of production planning unless later evidence and explicit approval reclassify it.

## Blank Write-Smoke Checklist

| Candidate ID | Approval date | Test role | Context | Sentinel | Expected visibility | Clear/reset method | Pre-state captured | Post-state captured | Result | Abort reason | Evidence session |
|---|---|---|---|---|---|---|---|---|---|---|---|
| none | none | none | none | `CS2_SMOKE_1` | none | none | no | no | not authorized | none | none |

## RuntimeProbe Boundary

RuntimeProbe remains read-only. This plan must not be implemented as a RuntimeProbe phase or default behavior.
