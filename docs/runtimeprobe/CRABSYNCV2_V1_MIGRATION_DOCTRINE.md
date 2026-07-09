# CrabSyncV2 v1 Migration Doctrine

This document is planning-only. It does not authorize CrabSyncV2 implementation, RuntimeProbe writes, mutating RPC calls, or local UE4SS runtime requirements.

## 1. Executive Summary

CrabInvSync v1 proved the concept of shared state sync for Crab Champions mod planning. It showed that lifecycle-aware state collection, metadata-aware payloads, cautious client roles, range clamps, and diagnostics are useful concepts.

CrabSyncV2 changes the architecture premise. It is not "v1 cleaned up"; it is a new P2P/game-native design that starts from RuntimeProbe evidence and the game's replicated state surfaces.

CrabInvSync v1 is retained as archival/prototype reference. It is not the CrabSyncV2 foundation, and its bridge/server/relay transport stack is not copied into v2 planning.

## 2. v1 Architecture Summary

CrabInvSync v1 used an external transport architecture:

- Lua game client code running in the mod environment.
- PowerShell bridge process outside the game.
- Node relay process outside the game.
- `push_<instance>.json` and `recv_<instance>.json` files as JSON IPC between Lua and the bridge.
- Room, players, and session model managed outside normal game replication.
- Server merge authority for combining external payloads.
- Apply-on-client model where clients interpreted merged state and attempted local apply behavior.
- Bridge polling and HTTP transport between local files and the relay.

This summary is v1-only archival context. None of these transport components are approved as the CrabSyncV2 baseline.

## 3. v1 Concepts To Keep

CrabInvSync v1 contains concepts that remain useful when mapped through current evidence gates:

- Lifecycle warmup and stability model.
- Joined-client caution.
- Role-aware behavior.
- Metadata-aware item payload shape like `{n,l,a,e}`.
- Full item comparison rather than name-only comparison.
- Range clamps for byte and UInt32 values.
- Diagnostic logging.
- Stale-state protection.
- Skip/abort behavior on instability.
- Explicit config gates for risky features.

These concepts are kept as design lessons only. Each one still requires RuntimeProbe evidence or explicit CrabSyncV2 sandbox proof before any implementation relies on it.

## 4. v1 Concepts To Discard For v2

The following v1 concepts are discarded for CrabSyncV2 baseline planning:

- External server/relay transport.
- PowerShell bridge process.
- `push`/`recv` JSON IPC files.
- Room password.
- Relay dashboard as authority.
- Server-side merge as default.
- Bridge polling.
- Treating arbitrary local JSON state as transport truth.
- Any assumption that external payload transport exists.

If any of these appear in future docs, they must be labeled as v1-only archival context or explicitly out of scope for CrabSyncV2.

## 5. v1 Risky Behaviors That Require RuntimeProbe Proof Before v2

The following v1-adjacent behaviors are not automatically safe for CrabSyncV2:

- Inventory array traversal.
- Element dereference.
- Item DA field reads.
- `InventoryInfo` reads.
- `Enhancements` reads.
- Raw `SetPropertyValue` writes.
- Official RPC calls.
- Joined-client read/apply behavior.
- Health apply or pooled behavior.
- Slot writes or slot RPCs.
- Any custom data carrier write.

RuntimeProbe proof means read-only evidence for reads. Write/apply behavior is not RuntimeProbe default behavior and requires separate CrabSyncV2-only sandbox planning and evidence.

Future write/apply behavior must follow [CrabSyncV2 Safe Write Path Discovery](CRABSYNCV2_SAFE_WRITE_PATH_DISCOVERY.md): passive observation first, official paths preferred, raw writes last-resort only, and no RuntimeProbe mutation.

[Write Path Unsafe Paths](WRITE_PATH_UNSAFE_PATHS.md) records write/apply paths that remain blocked or unsafe even when v1 prototype behavior suggests a possible approach.

## 6. v2 Doctrine

CrabSyncV2 follows these rules:

- P2P first.
- Evidence before implementation.
- Unsupported is a valid result.
- No gameplay-critical field hijacking for `CrabSyncBlock`.
- Official game paths are preferred over raw writes.
- Writes are discovered by passive observation first, then tested separately in a CrabSyncV2-only sandbox.
- RuntimeProbe remains read-only.
- CrabSyncV2 does not start full gameplay sync until readiness docs and evidence gates are satisfied.

The doctrine intentionally avoids reintroducing v1 external transport as a fallback. A server/bridge fallback is out of scope unless the user explicitly re-approves it in future planning.

## 7. Decision Table

| v1 feature/behavior | Preserve/copy/rewrite/discard | Reason | Required RuntimeProbe evidence | v2 status |
|---|---|---|---|---|
| Equipment sync | Rewrite | The concept is useful, but v2 must derive equipment identity from proven peer-visible game state and later prove a write path. | Remote equipment DA visibility, role stability, and future write-path sandbox evidence. | Likely P2P candidate; apply remains gated. |
| Crystals | Rewrite | v1 merge/sum ideas are useful, but crystals are gameplay state, not a custom payload channel. | Remote `Crystals` visibility, range behavior, and convergence inputs. | Likely P2P candidate; carrier misuse prohibited. |
| Slots | Rewrite | v1 clamping discipline is useful, but slot semantics are not fully resolved. | Slot visibility plus locked/max/total slot meaning across contexts. | Plausible P2P candidate; model unresolved. |
| Health | Rewrite | v1 health pooling informs design, but pooled health is not a vanilla runtime fact. | Remote `HealthInfo` visibility, convergence inputs, and later write/apply proof outside RuntimeProbe. | Read-only convergence planning only. |
| Inventory items | Rewrite | v1 item sync concept is useful, but traversal and item identity must be proven. | Safe array traversal, element dereference, item DA identity, and remote visibility or carrier proof. | Blocked. |
| Item metadata | Preserve concept, rewrite access | `{n,l,a,e}`-style metadata modeling is valuable, but RuntimeProbe must prove the actual fields safely. | `InventoryInfo.Level`, `AccumulatedBuff`, and safe parent item path evidence. | Blocked until metadata reads are proven. |
| Enhancements | Preserve concept, rewrite access | Upgrade preservation is required for non-destructive sync, but nested metadata is high risk. | `Enhancements` shape/count/value evidence through staged read-only phases. | Blocked. |
| Room/session identity | Rewrite | v1 external rooms are not v2 authority, but role/session awareness remains useful. | PlayerState identity/fingerprint and lifecycle evidence. | Use game-native session/player identity only. |
| Bridge transport | Discard | The PowerShell bridge is external transport and not game-native. | None; intentionally out of scope for v2. | v1-only archival context. |
| Server merge | Discard | Server merge reintroduces non-game-native authority. | None; intentionally out of scope for v2. | v1-only archival context. |
| Logging | Preserve concept | Diagnostics are required for evidence review and safe skips. | RuntimeProbe logging/evidence rows for relevant phases. | Keep. |
| Lifecycle state | Preserve concept | Warmup, role changes, joins, travel, respawn, and instability gates prevent stale behavior. | Lifecycle observe/read evidence across contexts. | Keep and strengthen. |
| Joined-client behavior | Rewrite | v1 caution is valuable, but joined-client safety must be independently proven. | Joined-client replay of proven read phases; later sandbox write proof if ever needed. | Read-only by default. |
| Diagnostics/dashboard | Rewrite | Diagnostics are useful, but relay dashboard authority is not copied. | Local evidence/log docs only. | Keep diagnostics; discard dashboard authority. |
| Config gates | Preserve concept | Risky phases must stay explicit and disabled by default. | Gate-specific RuntimeProbe manifests and evidence rows. | Keep. |
| JSON payload model | Rewrite | v1 JSON payloads help describe normalized state, but are not transport truth. | Evidence-backed local snapshot schema and unsupported-field markers. | Internal planning/schema concept only. |
| Apply engine | Rewrite | Plan/skip/abort concepts are useful, but all writes need separate proof. | Passive observation, write-path discovery, and CrabSyncV2-only sandbox write-smoke docs. | Future, disabled. |
| Write/RPC behavior | Rewrite from evidence | v1 behavior does not prove UE4SS writes or RPCs are safe. | Official path discovery, no-mutating RuntimeProbe evidence, and separate sandbox write-smoke evidence. | Not approved. |

## 8. Category-By-Category Migration Notes

### Equipment

v1 shows that equipment identity sync is a useful category. CrabSyncV2 must use P2P-visible DA identity under [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md) when evidence proves the visibility is stable, then separately prove any write/apply path outside RuntimeProbe.

### Crystals

v1 sum/merge thinking is useful for planning resource convergence. CrabSyncV2 must derive crystals from visible state under [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md); it must not use `Crystals` as a custom carrier, and keys remain excluded unless explicitly re-approved.

### Slots

v1 range clamping is useful because slot-like fields are byte-range values. CrabSyncV2 still needs the slot-model evidence listed in [CrabSyncV2 Resource P2P Model](CRABSYNCV2_RESOURCE_P2P_MODEL.md) before planning apply behavior.

### Health

v1 experimental health pool behavior can inform design questions, but pooled health is not a vanilla fact. CrabSyncV2 starts with read-only convergence planning from PlayerState-scoped health evidence under [CrabSyncV2 Health P2P Model](CRABSYNCV2_HEALTH_P2P_MODEL.md).

### Inventory

v1 item payload modeling is useful because it avoids name-only item comparison. CrabSyncV2 still requires the proof ladder in [CrabSyncV2 Inventory Item Proof Plan](CRABSYNCV2_INVENTORY_ITEM_PROOF_PLAN.md) for traversal, item identity, `InventoryInfo`, `Enhancements`, duplicate semantics, joined-client replay, and either remote visibility or a reviewed safe carrier decision before full inventory sync can be planned.

### Transport

v1 transport is discarded entirely for CrabSyncV2. No PowerShell bridge, Node relay, room password, relay dashboard, push/recv JSON IPC, or server-side merge authority is part of the v2 baseline.

[CrabSyncV2 P2P Carrier Research Plan](CRABSYNCV2_P2P_CARRIER_RESEARCH_PLAN.md) is v2-specific research for a possible game-native `CrabSyncBlock` carrier. It is not a copy of the v1 bridge/relay transport and does not assume a carrier exists.

## 9. Acceptance Rule For v2 Code

No CrabSyncV2 code starts until design docs and evidence gates are complete.

Full inventory sync waits for item identity, `InventoryInfo`, `Enhancements`, and remote visibility or carrier proof.

Any write/apply executor waits for safe write-path discovery and sandbox write-smoke docs.

No server/bridge fallback is allowed unless the user explicitly re-approves it in the future.
