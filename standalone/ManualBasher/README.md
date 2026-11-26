# ManualBasher — manual walking, standalone Mudlet package

## Load at home
1. Use a separate **clean Mudlet profile** for your Aetolia character. Do not import CombatV2 or another attack/defence automation package. This package refuses known competing globals; it cannot detect every possible client script.
2. In Mudlet open **Toolbox → Package Manager → Install**, select **ManualBasher.xml**. Do not paste the XML into the script editor. The XML contains all code and the complete area catalog; no Lua files need copying and no PC-specific paths are used at runtime.
3. Enable GMCP in your profile connection settings, then disconnect/reconnect so fresh character/affliction/room events arrive. Import/reload/reconnect always starts **OFF**.
4. Walk manually into a supported hunting area. Type `mb status`, `mb refresh`, then `mb on`. Stay at the keyboard. `mb off` immediately stops future automatic commands. You still move and handle safety yourself.

Default: class **Earthcaller**, attack **quash {target}**, Irongrip wanted **ON**. The active native class must match; no guessed class fallback.

## Commands
- `mb on`, `mb off`, `mb status`, `mb help`
- `mb command quash {target}` — OFF only, exactly one numeric NPC target placeholder; no command separators/control characters.
- `mb class Earthcaller` — OFF only. Other commands/classes are user configuration, not certified class adapters.
- `mb area <preset>` — OFF only, explicit single catalog preset when the native area's alias differs. `mb area auto` restores native exact alias matching. Unknown/ambiguous areas block attacks. See `mobs.json` keys for preset IDs; this is not a universal union of targets.
- `mb irongrip on` / `mb irongrip off` — OFF only. Off stops upkeep, never sends RELAX.
- `mb refresh` — explicitly sends LOOK and requests a room item list. If an older request is outstanding, its response is discarded before requesting again. If the server never answers, reconnect to clear the barrier.

Irongrip: ON first makes one `racial help irongrip` query if current-connection knowledge is missing. It must observe the Irongrip help heading and `Known: Yes`; it never selects racial skills or spends slots. Actual defence List/Add/Remove or the exact own gained/lost line tracks activity. If already observed active, no activation is sent. Otherwise IRONGRIP shares the attack scheduler: one command, own defence acknowledgement, raw BAL loss/recovery, then a later native prompt before attacking. Failed/missing acknowledgement stops the basher after ten seconds; no blind retries.

## Boundaries / important caveats
- No movement/following, re-wielding, curing, Splinter, resource-spending combat abilities, sacrifices, FIRSTAID changes, periodic ability/defence scans, keyboard locks or command rewriting.
- Only exact catalog names in the current selected area, numeric IDs, positive `m` NPC attribute, and deliberately narrow known/nonprotected icons qualify. Players, loyal/vendor/corpse/mount attributes and whole-word guards/horses/steeds/mounts/rocs are rejected. `mountain crocodile` is not rejected by a substring bug. Unknown flags/icons hold rather than guess.
- Fresh native HP/BAL/EQ/prone/arm balance and a complete native affliction snapshot are required. Earthcaller requires a current native `wield_left`/`wield_right` nonempty item token. Missing fields HOLD with a reason; it never equips or struggles automatically. Below 20% HP switches OFF with a prominent warning; exactly 20% is not the low-health cutoff. No fleeing is performed.
- One send per actual raw BAL loss/recovery cycle and subsequent prompt, with a 0.30s minimum throttle. Repeated ready vitals/prompts cannot authorize an additional hit. OFF retains an outstanding action until actual recovery; it does **not** cancel a command already sent to the server. Manual attacks can make evidence ambiguous: do not mix physical automation/actions while armed.
- A real Room.Info room-number change immediately clears the target/snapshot. A single-flight room-list request drains an outstanding pre-move response before a new request. **Char.Items.List has no room ID/request token. This protocol cannot certify response-to-room correlation**: unsolicited/duplicate/interleaved lists from another producer can still be ambiguous. Use the clean profile; if anything is inconsistent, OFF, LOOK/refresh (or reconnect), inspect the room, then deliberately ON. This is a conservative freshness barrier, not a guarantee against all protocol reordering.
- Ten-second timers only stop unanswered actions/queries; timers never attack or poll. No unattended-play or live-safety guarantee. Tested entirely offline, not inside Mudlet or against the game. Removing ManualBasher in Package Manager cleans up its owned aliases/events/triggers/timers.

## Source and offline verification
`ManualBasher.lua` is the injectable pure factory; `install.lua` binds Mudlet APIs; `mobs.lua`/`mobs.json` are the read-only exported catalog (106 area presets, 710 unique exact names). `ManualBasher-bundled.lua` is the self-contained XML script. `build.py` deterministically packages these sources; `SHA256SUMS` records artifacts. `tests.lua` tests core behavior; `tests-install.lua` tests bundle import/reload/uninstall using mocked Mudlet APIs. Run either test with Lua and this directory as its first argument. No tests invoke a real client or game connection.
