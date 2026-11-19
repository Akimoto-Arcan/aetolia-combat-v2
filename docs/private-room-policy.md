# Private room BASH approval

`policy.init` optionally reads `<getMudletHomeDir()>/combat_v2/bashing-rooms.json`
using `io.open` and `yajl.to_value`. Keep this profile-local file outside Git.
Example with a **synthetic** room number:

```json
{"approved_rooms":{"73077":true}}
```

The root must contain only `approved_rooms`; its value must be a map whose keys
are canonical positive-integer strings and whose values are literal `true`.
Numeric keys, zero/negative/fractional IDs, leading zeroes, wildcard keys and
other truthy values are rejected. Any invalid entry rejects the entire map.
Missing facilities or a missing file grant no new permission; unreadable or
malformed settings do not grant private-room permission. Loading settings never
arms combat, sends commands or writes files.

`policy.set_approved_rooms(state, map)` validates and copies the map into
`state.policy.approved_rooms`; invalid input clears that map and returns false.
The approval applies only to the exact current `state.room.id`, including after
room title/area renames. AREAS-list refreshes do not erase this separate map.
Unknown/invalid room identity always denies permission, even in an otherwise
approved area. Other room IDs do not inherit this exception; ordinary area
approval/consent rules remain unchanged.

Room approval does not bypass current occupancy, solo/web roster freshness,
target confirmation or protected/dead/guard/non-monster checks. It neither
authorizes travel nor changes class selection. Offline tests use fake I/O and
an explicit decoder stub, never a real profile or a global fallback.
