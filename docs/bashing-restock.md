# Independent Bashing Restock

`cv2 restock on|off|status` controls **restock permission**, independently of
GLOBE. The bootstrap entry point is `restock_boot.attach(c)` (also `bind`). It
attaches OFF, installs `combat_v2_restock(action)` in the supplied API/global
namespace, and never starts BASH, reads saved permission, travels, audits supplies,
or purchases merely because it was attached or enabled.

## User behavior

- ON can be selected while combat is OFF; it waits for actual BASH.
- During BASH, an authoritative health FC or anabiotic IC reserve **strictly below
  200** reserves the next walker hop/GLOBE spawn. Exactly 200 is not low.
- Continue pressure against the current NPC and preserve native FIRSTAID. A
  reservation must not become a blanket physical/mental hold. Already-issued
  attacks, walker hops and their arrival/IH barriers, buffs, DRAIN/SUMMON and
  other resource transactions must settle before the owned shopping pause.
- At a genuinely clear, fully recovered gap, capture the exact current room AND
  area, class/session/intent, upkeep master, GLOBE intent and walker checkpoint.
  Capture occurs before the owned mode OFF/PT. There is no fixed hunting room.
- Compare current DIRECTORY candidates from the public Spinesreach directory,
  verify actual WARES stock/unit/price, obtain one bounded targeted cache baseline
  and carried-wallet baseline, then purchase toward health 1500/anabiotic 2000.
  Skip an already-at-target kind. No bank, organizational funds, globes, class
  commands, cure-priority resets, container-helper reset, API or model dependency.
- Return by the existing native PT owner to that exact room/area. Require a fresh
  solo player list (not a WEB exception), real readiness, owned BASH restoration,
  fresh actual room-IH evidence and unmounted recovery before restoring walking.
  A return NPC gets ordinary BASH priority before checkpoint restoration. The
  walker owns the saved graph/cursor/visited/consent and restores it once, without
  a popup or a new path. It must discard old clearance/exits/occupancy and require
  another fresh post-resume inspection before its next hop.
- Restore GLOBE only if it was originally armed and remains desired. Public GLOBE
  OFF cancels only that saved spawn intent, never the restock toggle. Stationary
  or walking BASH never gains a new GLOBE intent as a shopping side effect.
- The temporary independent `c.xp_globe_cutoff` observer is neither replaced nor
  detached. An enabled, triggered XP latch suppresses rearm/initial summon and
  leaves ordinary BASH and the independent restock toggle intact. After rebinding
  public GLOBE functions, the migration owner must rebind that observer's guard.

### OFF versus STOP

`restock off` prevents new trips without stopping BASH. Before lease acquisition,
it cancels the reservation without movement. After acquisition, it keeps the
existing transaction owner alive: skip all unissued purchases, settle an issued
BUY/required INCALL with receipt/cache/wallet evidence, and make only the bounded
exact return. Restore the original still-consented BASH/walker/GLOBE intent while
leaving restock permission OFF.

Explicit operator combat OFF (including already-OFF), another mode selection,
manual target/queue changes, fresh walking consent, class/session change,
unexpected movement, death or disconnect revoke automatic resume. No unknown
purchase/route/hop barrier is cleared or retried. A known issued native route can
still settle its location after revocation, but cannot continue the itinerary or
resume combat. Faults require reviewed recovery; ON cannot bypass them.

## Module interfaces and integration

Owners are deliberately distinct from the deprecated lunch library:

```
c.restock_module      -- restock.lua
c.restock_boot        -- restock_boot.lua
c.restock_controller  -- injected-IO FSM and owned native hooks
c.restock_data        -- controller state, exact shared activity lease
c.user_activity == c.restock_data -- while the trip owns the client
```

`restock.lua` exports:

- `new(io, settings, state)`; construction is pure. Settings do not grant ON.
- `adapter(c, api)`, `attach(c)`, `detach(c)`; detach refuses unresolved ownership.
- `command(c, action) -> bool, reason/status`, `tick(c)`, `text(c,line)`, `prompt(c)`.
- `user_stop(c)` increments `c.restock_intent_epoch` and revokes resume consent.
  Core target/queue-next/STOP/session boundaries must call this; automatic NPC
  kill-chain selection must not impersonate a manual target change.
- `globe_off(c)` revokes saved GLOBE resume intent only.
- `busy(c)` holds other discretionary producers after the owned pause or while
  any issued transaction is unresolved. It is NOT the toggle's enabled value.
- `movement_reserved(c)` inhibits NEW walker hops and NEW globe cycles during the
  low-stock reservation, without stopping offense or settlement of prior actions.
- `owns_transition(c)` recognizes only a valid exact lease's trusted synchronous
  pause/route/resume dispatch (including a native owned asynchronous route pause).
  Core/walker must exempt these internal mode transitions from user revocation.
- `movement_borrowed(c)` validates active native PT owner identity, destination and
  serial against the pending restock route. It also covers the exact acknowledged
  final destination while restock has not yet consumed its native arrival. This
  does not authorize unrelated/manual PT.
- `room_changed(c,room,area)` is also available to core. Attachment already owns a
  genuine `gmcp.Room.Info` observer, installed AFTER canonical core ingestion. Do
  not feed it cached Room.Info or run it before core updates room/walker state.

FSM public state: `enabled` is permission; `active` is controller servicing;
`reserved` inhibits new movement/spawns; `busy` is the acquired activity lease;
`resume_consent` is revocable return permission. Stages are `idle`, `monitor`,
`drain`, `pausing`, `route`, `directory`, `wares`, `baseline`, `inventory_before`,
`buy`, `incall`, `readback`, `inventory_after`, `return_check`, `resume`, and
`initial_wait`. `destination` plus `pending.kind=='route'` identify the only
borrowed PT. `after_route` is the next stage. Faults retain pending/purchase state.

`restock_boot.attach/bind(c,api)` wraps trusted public mode/GLOBE functions and
travel request/recall lanes idempotently. It exposes `busy(c)`, `hold(c)` and
`reserved(c)`. Bootstrap `busy` exempts only the exact lease's synchronous
read-only checkpoint-capture scope (`capturing_checkpoint`) and trusted resume
dispatch, so upstream convenience/CP guards cannot self-deadlock. Public status
and action gates still use module `busy`, which remains true. `hold` allows owned
return BASH preparation only after transactions are settled; real runner/resource/
player gates still apply. A deferred recall may also settle at the exact owned
return anchor once native route intent/pending are resolved; native recall's own
reservation continues holding offense until its actual receipt/recovery. Balance-free FOLLOW
and server FIRSTAID remain independent. Native async PT servicing must remain
available for `movement_borrowed`, not be blocked by a generic convenience hold.

### Walker checkpoint contract

Use the **native** `c.walker_boot` API, not the pure `c.walker` planner. A
`c.walker_module` native alias is supported for compatibility:

```
restock_ready(c, lease) -> bool, reason
restock_suspend(c, lease) -> checkpoint, reason
restock_resume(c, checkpoint, lease) -> bool, reason
restock_cancel(c, checkpoint, lease, why)
```

`cp.lease` must be the identical `c.restock_data` object; `cp.room/area` must match
the captured anchor. Area is exactly canonical `s.room.area` (normally a native
string), never a mapper numeric `area_id`/`cp.walk_area`. The remaining graph/cursor/visited/token/generation/intent
fields are opaque and remain walker-owned. An explicit `false` checkpoint means
stationary operation; `nil` means failure, never permission to silently discard a
walker. Readiness must include pending hop and post-arrival inspection barriers.
Resume `false,'awaiting ...'` defers without restoring or clearing anything; other
false results latch a fault. Successful restore is never repeated.

Pure IO uses `walker_ready`, `walker_arriving(room,area)`, `checkpoint(lease)`,
`restore_checkpoint(cp,lease)`, and `revoke_checkpoint(cp,lease,why)`. The additional
arrival predicate recognizes only an already-authorized hop/arrival, not general
readiness failures or an NPC fight; an arbitrary manual room change cannot be
blessed just because `walker_ready` returned false.

## Evidence and bounds

- Default monitoring uses existing passive FC/IC stock versions; it never polls
  IC/FC/pipe/container lists. At a shop, use existing `supplies.audit` for exactly
  the relevant baseline and post-purchase cache source. Preserve quarantine.
- Reserve pending/dispatch state before invoking senders. False/throwing senders,
  synchronous callbacks and nested ticks cannot issue another BUY or credit a
  staged result. Query versions are captured at actual dispatch.
- Require DIRECTORY header/divider/footer, native WARES proprietor/header/footer,
  singular units, verified stock and price agreement. Duplicate WARES item rows,
  unknown units, quotes and missing framing fail before purchase.
- Health is bought in whole 50-sip refill units, rounding up toward the target.
  Require the exact own receipt's total sips/cost, then an authoritative FC result
  at least 1500 and no greater than baseline plus purchased sips. The fixture for
  non-multiple/capped results is synthetic, not a claim of native cap behavior.
- Anabiotic units are accepted only from explicit singular `an anabiotic pill` or
  `anabiotic pill` WARES descriptions. **The actual native anabiotic WARES unit has
  not been observed.** An unknown real format fails closed before BUY; hypothetical
  singular-unit fixtures do not certify live support. No purchase ACK is invented.
  BUY alone cannot prove IC: required INCALL plus a fresh absolute IC result and
  exact carried-wallet delta must settle the transaction.
- Native wallet grammar is anchored `You are carrying N gold sovereigns.`. Require
  enough carried gold before BUY and the exact charged delta afterward.
- At most three directory candidates per kind; 100 stored rows per query, 300
  response lines, 1000 characters per line, 60 seconds per non-route transaction,
  300 seconds per route, 600 seconds waiting for the fight-clear gap, 1800 seconds
  per trip. Timeouts retain unknown barriers; they are not arrival/receipt proof.

## Hot migration (integration owner)

1. Pin/review the composed source and tests; do not deploy a moving checkout.
2. Preserve runner/mode/target/recovery, supply ledger and container quarantine,
   GLOBE commitments, walker consent/hop/arrival barriers and XP observer identity.
3. Retire the legacy lunch owner ONLY while idle and with no pending resource or
   movement transaction. This new module never retires it or aliases its state.
4. Restore public mode/GLOBE entry points from the trusted core definitions or an
   explicit trusted API table; do not wrap the old lunch GLOBE-OFF cancellation
   closure and do not edit Lua upvalues. Bind restock guards, then rebind the
   temporary XP GLOBE guard. Preserve its original observer/handler objects.
5. Wire reservation/new-action versus busy/settlement-only gates in core, walker,
   GLOBE, physical/mental/upkeep/container/travel adapters. Permit actual owned PT
   pumping, native receipt bookkeeping, native curing and return preparation.
6. Add module manifests, command branch, GUI enabled-state button and test runner
   entries in the integration owner's files. Normal startup always remains OFF.
7. Run the sealed composed bootstrap/walker integration and hot-binding suites in
   standalone Lua 5.1 and 5.4, then perform separately authorized native compile/
   readback. These new module tests are offline fakes, not live traversal proof.

Standalone commands (from the source root):

```
/home/chris/.hermes/cache/scratch/ledger-lua51/lua-5.1.5/src/lua tests/restock.lua .
/home/chris/.hermes/cache/scratch/ledger-lua51/lua-5.1.5/src/lua tests/restock_boot.lua .
lua tests/restock.lua .
lua tests/restock_boot.lua .
```
