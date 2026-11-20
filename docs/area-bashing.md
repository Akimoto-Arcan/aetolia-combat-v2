# Native area-bashing presets

This is an **offline-tested source implementation**, not a deployed hunting run.
Installation and reload remain OFF. Selecting a preset never sends a query,
attacks, changes combat mode, or authorizes walking.

## Operator surface

- `cv2 area list`: deterministic preset keys.
- `cv2 area select tcanna`: choose the Tcanna catalog in the matching current
  area. Stop walking first. Existing area-policy approval remains independent.
- `cv2 area status`: selected preset, exact bound area and controller diagnostic.
- `cv2 area off`: return to the existing stationary hunting queue selector.
- `cv2 area pressure 1` through `4`: Tiyen cutter-only HOLD threshold; default 4.
  This revokes walking consent. It never retreats or skips into another room.
- Explicitly enable `cv2 bash`, then accept the existing current walking offer
  with a fresh YES (`cv2 walk yes`). Or remain stationary / decline walking.
  `cv2 walk on` requests a new offer; selection alone grants no travel permission.
- `cv2 area yes|no` still refers to area-policy consent, not walking or presets.

`combat_v2_area_configure(preset, exact_current_area, room_set, encounter_names)`
is the OFF-and-settled-only private configuration entry point. `room_set` is an
explicit `{["mapper-room-id"]=true}` allowlist, never a list of invented IDs.
The configuration is session-only and not automatically saved. Room graph data
comes from the existing guarded mapper adapter, not legacy direction lists.
The native graph filters private room sets and rechecks destination membership
before dispatch. Review coverage: special exits, doors, weighted/locked rooms,
one-way links and disconnected components are not promised traversal.

## Catalog and evidence

21 named entries correspond to the Fallout starters (Top/All Xaanhal are
separate). 211 deduplicated area/NPC rows quote active AC2.2
`Msys / Bashing / Moblistings` sections. Every row retains its source section,
comment evidence, priority and separate aggression classification. This is a
hunting whitelist, **not** a claim every NPC is aggressive. Conditional `some
aggro` comments remain non-aggressive metadata. Literal source headings are
selection labels, not invented GMCP aliases: if the actual area spelling differs,
review and bind the exact observed area using private configuration.

Default priority is 10. Explicit AC2.2 aggression comments receive 100. Native
priority policy prefers evidenced aggressors; this numerical ranking is new
selector policy, not a quotation of an AC2.2 rotation. Tcanna python receives
200 based on Fallout `Python Target trigger`, `Python here` and the many
`if not python_here` animal guards. Tiyen cutter receives 200 based on Fallout
`Cutter` / `Cutter here room message`; count distinct current cutter IDs, HOLD
at the configured threshold, rather than importing `expandAlias("tiyen")`.
Other Tiyen aggressive entries retain their AC2.2 evidence independently.
Neither monster icon nor NPC membership means aggression.

Selection resolves exact full NPC names to IDs in the current certified full
room Items.List. The highest priority wins, an equal-priority current target is
kept, otherwise numeric ID order is deterministic. Duplicate names with distinct
current IDs are not duplicate attacks; duplicate IDs/malformed/sparse lists are
rejected. Corpses, loyal mounts and player-marked items are excluded. Unknown
living NPCs block clearance and movement rather than being silently skipped.
Partial updates invalidate certification and require a new full list.

The actual BASH IH selector and actual bootstrap tick consume this catalog.
Higher-priority arrivals can replace an existing lower-priority target only
after committed physical/mental/shared-resource work settles. Re-selection
invalidates old target authority and never changes the Monk action recipe.

## Encounter ingestion and remaining configuration blockers

Only the existing owned native line ingestion is extended. No AC2.2/Fallout
trigger is installed, enabled, imported or executed. Exact knight shield and
shield-destruction narratives and the intended slime-nest spawn sentence are
translated into room/session-scoped markers. Markers expire on room/area scope loss,
disconnection and reload; unchanged same-room metadata preserves protection; quoted/substring other-actor messages cannot arm them.

The legacy references specify target tokens `shard` and `nest`, but do **not**
establish their exact full GMCP NPC names in the extracted hunting catalog.
Do not guess these names. Supply reviewed `encounter_names={shard=...,nest=...}`
through private configuration. An unconfigured encounter **HOLDS**, rather than
attacking the knight through protection or an arbitrary substring target. The
knight's exact name defaults from the narrative; it can be explicitly configured.
Shard completion requires the matching current-room marker and our selected
exact configured shard target, then selects the knight. Own native target-slay
handling releases knight/nest markers; unrelated deaths cannot release them.
This provenance check is conservative narrative/target correlation, not a claim
of server-provided actor or item-ID attribution for the destruction sentence.

Fengard and Top Xaanhal require reviewed private room allowlists: legacy
exclusions/top-only routes must not become full-area permission. The Ylem entry
is intentionally not an operational mob catalog: legacy `eld` is a token with
DIG/GREET/shackle side effects, without an exact scoped mob-name table. Its room
configuration alone does not create NPC eligibility. Alaqsii and other catalogs
may be incomplete relative to current game populations; unknown NPCs HOLD.

Quest GIVE/DIG, sacrifice, healing, legacy routes, blind fallback movement and
legacy boolean/operator-precedence bugs are not ported.

## Walking, GLOBE and restock

The existing walker remains the only navigation controller. Fresh scoped YES,
area/player policy, recovery, fresh solicited IH, exit verification and issued-hop
ACK barriers remain mandatory. Even an unmatched unknown living NPC prevents
`mark_clear`; stale text-only emptiness cannot move. GLOBE remains mutually
exclusive in both directions, including suspended active-walker checkpoints.

Independent native RESTOCK retains its existing identity-bound
suspend/checkpoint/return/resume contract. Preset state is independent of target
ID and route cursor. Returning cannot reuse pre-trip item certification: fresh
inspection and recomputation are required. Existing full walker/restock suites
cover restoration and route identity; the added actual-bootstrap fixture checks
preset consumption, multicast Room.Info ingestion, suspend/cancel and no
premature resume. No real shop trip or native traversal is claimed.

## Tests and release boundaries

`tests/areas.lua` tests the real send-free selector and catalog.
`tests/areas_boot.lua` runs actual bootstrap with offline multicast native API
fakes and real walker/restock modules. Both are registered in `tests/run.py`;
`areas.lua` is required by the installer manifest. Run the normal suite and each
registered Lua fixture separately in Lua 5.1 and the supported current Lua.

Deployment is a separate parent-owned operation. For a preserved-owner hot
release, rebind `c.areas`, `c.bashing.bind_areas`, the BASH IH/tick consumers,
item callbacks, room/disconnect/line consumers, area command surface and walker
graph/clear/step functions from the same sealed artifact. Merely replacing
`mobs.lua` or publishing a module does not install target priorities. Preserve
runner/wait/shared-owner identities; do not rerun constructors or these tests
in a connected client. Monk, healing modules and GUI geometry are unchanged.
