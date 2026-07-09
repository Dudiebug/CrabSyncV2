# P2P Carrier Visibility Matrix

This is a future template/status document for read-only P2P carrier visibility evidence. No carrier visibility matrix exists yet, and this document does not prove or authorize any carrier, write, RPC, or payload.

Visibility is read-only proof. It is not write proof.

Future row updates should follow [P2P Carrier Evidence Mapping](P2P_CARRIER_EVIDENCE_MAPPING.md).

Use [P2P Carrier Readiness Checklist](P2P_CARRIER_READINESS_CHECKLIST.md) for decision outcomes after visibility rows exist. Visibility remains read-only proof, not write proof.

## Visibility Directions

- `local-only`: visible only on the local client.
- `host-to-client`: value or event is visible from host source to joined client observer.
- `client-to-host`: value or event is visible from joined client source to host observer.
- `client-to-client`: value or event is visible from one joined client to another joined client.
- `host-only`: visible only on host.
- `joined-client-only`: visible only on joined client.
- `all-visible`: visible to all required roles in the tested context.
- `unknown`: not tested or inconclusive.

## Test Contexts

Future rows should identify one of these contexts when applicable:

- `solo`.
- `host in lobby`.
- `joined client in lobby`.
- `host in run`.
- `joined client in run`.
- `during join`.
- `after travel`.
- `after respawn`.
- `disconnect/reconnect` if later tested.

## Matrix Columns

Future matrix rows should use these columns:

- Candidate ID.
- Context.
- Local role.
- Remote role.
- Direction observed.
- Value changed naturally?
- Update cadence.
- Stale behavior.
- Raw/private value emitted?
- Evidence session.
- Result.
- Notes.

## Placeholder Matrix

| Candidate ID | Context | Local role | Remote role | Direction observed | Value changed naturally? | Update cadence | Stale behavior | Raw/private value emitted? | Evidence session | Result | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| none | unknown | unknown | unknown | unknown | unknown | unknown | unknown | unknown | none | no current matrix | Future read-only carrier visibility evidence belongs here. |

## Read-Only Boundary

Carrier visibility evidence may show that a natural vanilla value/event replicates. It does not show that CrabSyncV2 can write, trigger, clear, or safely encode `CrabSyncBlock` data through that path.
