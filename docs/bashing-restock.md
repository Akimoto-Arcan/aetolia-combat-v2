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
- Native WARES has now proved the alphabetic SKU `anabiotic` with explicit singular
  `an anabiotic pill` description. Accept exactly that SKU (and legacy `pillNNN`
  fixtures), never arbitrary alphabetic purchase words. Health remains `caskNNN`
  only. Native BUY/INCALL were observed separately; no purchase ACK is invented.
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

## Conditional private Haven routing (source candidate; not native deployment)

Optional **private profile** `combat_v2/restock-settings.json`:

```json
{"haven_room":"73009","globe_haven_return":true}
```

The ID above is a synthetic example, NOT an account destination. The integration
owner supplies the actual individually authorized ID privately after review.
`settings_json(raw)` parses only these two fields, rejects duplicate/unknown keys,
numeric IDs, leading zeroes, executable text and trailing commas without evaluating
Lua. `read_settings(api)` reads at most 1025 bytes under `getMudletHomeDir()`.
Absent config preserves ordinary exact-origin behavior; malformed config produces
`c.restock_settings_error` and does not grant a Haven policy. Permission still starts
OFF. Config does not approve bashing in that room: private bashing policy remains a
separate exact-ID permission.

At the natural low-stock trigger, capture **current desired GLOBE intent**, not the
later internal spawn-suppression flag (`desiredOnCurrent` when available, otherwise
current `armed`). Only GLOBE ON + explicit Haven config selects this itinerary.
GLOBE OFF keeps the existing ordinary walker checkpoint, exact canonical area,
cursor/steps/visited/consent and return PT unchanged; zero Haven commands are sent.
Haven policy is valid even if the trip starts outside the configured room.
`origin_room/origin_area` retain the actual departure scope independently from
`return_room` (the requested Haven ID). Haven policy never fabricates a walker
checkpoint or grants walking consent; an active walker is refused rather than
silently transferred.

Inside the exact configured ID, finish the fight/commits/arrival scan, acquire the
owned OFF pause, issue `exit haven` once (`haven_exit`) and wait for **actual different
full Room.Info plus subsequent ready prompt**. Never infer the outside destination.
Then use ordinary PT/directory/stock/wallet purchases to top off BOTH caches. At
`haven_wait`, native FIRSTAID remains independent; wait up to 120 seconds for HP
**>= maxhp** and mana **>= maxmana**, positive maxima and genuine readiness. Issue
`return to haven` once (`haven_return`), never PATH FIND to the unmapped private ID.
An actual matching full Room.Info and subsequent ready prompt settle it; names and
area labels are not permission/arrival keys. Wrong/partial packets and 20 seconds
elapsed do not prove arrival. Issued transport has a 120-second unresolved deadline,
not timer-based completion or retry. Existing strict fresh solo players, native
BASH preparation/IH, unmounted recovery and GLOBE ownership gates then apply: BASH
mode restoration initiates the existing native IH procedure, but attacks/GLOBE or
walker restoration cannot bypass its actual evidence. Renaming the private room
or area does not change the approved numeric identity.

Public GLOBE OFF before Haven return is issued cancels that return and stops the
automatic trip OFF with a recoverable diagnostic; it never starts ordinary walking.
After issue it cannot unsend the transport; settle only actual arrival, never
restore GLOBE/walking from the revoked grant. XP cutoff independently suppresses
new GLOBE rearm/summon. STOP/session/class/disconnect revoke resume separately and
retain any issued transport. A false/throwing sender retains UNKNOWN even if its
nested callbacks staged an apparent arrival. No unknown BUY/GO/FOLLOW/DRAIN/buff
barrier is cleared.

Mount convenience is outside-plane only. `travel.haven_deferred(c)` saves only
**unsent** follow/recall intentions in `c.haven_handoff.deferred_follow` with exact
owner/episode/session/item-version identity. It never clears pending FOLLOW/RECALL
or a fault. Resume only after real exit and a newer full outside Items snapshot
for the same owner/session. A pre-existing older deferred record lacking session
proof is deliberately held for reviewed migration, not silently blessed.

### Cooldown and recoverable failures

The exact native `You cannot find a new path so soon.` line belongs only to the
current pending FIND. A subsequent real prompt settles that read-only refusal.
Retry the **same** destination after two seconds, at most three total attempts.
Each needs new framed route proof and another real prompt; old proof/backoff never
grants GO. Speech/unsolicited lines do not cancel an issued GO. Exhaustion returns
a typed `travel_owner.refusal.kind == 'find_cooldown'`, not a transport fault or a
more expensive shop fallback. Unknown FIND timeout/false/throw remains quarantined.
A revoked leased trip may settle its FIND response, but cannot promote it to GO.
Exact numeric already-here PT uses actual current room identity and sends no FIND,
mount or GO (it still requires the existing readiness and owned pause).

Completed directory/wares parse failures, verified no-money/no-stock/no-resource
outcomes, and proven FIND cooldown exhaustion stop the automatic trip, retain
FAULT/history (`last_readonly`, `last_find_rejection`) and revoke resume. Release
only this lease when pending/purchase/dispatch are absent and native action owners
prove no unresolved movement/resource state. Leave BASH OFF, but explicit modes,
GLOBE, status/settings/help/OFF remain usable through existing UI callbacks; no GUI
redesign or blanket callback disable. Restock ON still requires reviewed recovery;
explicit combat permission does not clear the retained diagnostic. Unknown query,
BUY, GO, FOLLOW, resource or Haven transport continues to inhibit affected actions.

### Review / hot-bind handoff

Run the sealed full legacy suite in **both standalone Lua 5.1 and 5.4**, plus:

```
lua tests/restock_haven.lua combat_v2/
lua tests/travel_cooldown.lua combat_v2/
```

The integration owner must register these two new files in its test runner; this
worker does not own `tests/run.py`, bootstrap, GUI, installer or manifests. Existing
`restock_composed.lua` adds real-bootstrap multicast Haven and recoverable-control
regressions (synthetic GameIO only), alongside the ordinary steps=17 checkpoint
roundtrip. Full two-cache buys and alpha cheapest SKU are exercised in isolated
FSM tests; do not call that a native automatic trip.

For an idle, unarmed existing restock owner, retire only its owned hooks/timer using
its existing detach, replace the three reviewed modules and bind to trusted APIs;
`new(adapter, settings, exact_old_state)` is available for an explicitly reviewed
state-preserving rebind. Do not infer permission from prefs or load armed state.
Retire/rebind travel only when no pending/dispatch/fault/intent/route/follow/recall
exists; mount/follow continuity must be migrated explicitly, never by replacement
of a busy owner. Recreate/rebind captured adapter closures and convenience holds,
then rebind the XP observer's public guard without changing its identity. Compile
pinned bytes offline before any authorized native handler replacement. Do not run
these fixtures in Mudlet or full-bootstrap the currently active BASH/GLOBE session.

Native Haven interruption/rejection text has not been documented here; an issued
return without actual matching room+ready proof therefore holds to timeout as
UNKNOWN and never retries. No native/client/network action or private config write
was used to validate this candidate. Deployment and a later **natural** low-stock
Haven trip require the integration owner's independent review and native readback.
