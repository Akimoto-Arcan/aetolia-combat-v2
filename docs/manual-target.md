# Explicit room-local target priority (offline candidate)

Use the existing `t 123456`, `cv2 target 123456`, or Combat V2 target GUI control.
An unambiguous whole-word NPC keyword also works: `t gnarled`.
Use `cv2 bash` to enable BASH; `cv2 off` stops it. No new attack alias or sender.
Keep WALK OFF for stationary hunting; movement still needs its existing separate consent.

- Select while BASH is ON, or select before enabling it in the **same actual room**.
- A current solicited complete room list and a subsequent prompt must certify the NPC.
  Before certification, selection is intent only; OFF cannot attack. The ordinary
  OFF target display/API is preserved, but BASH resolves a numeric ID afresh.
- The selected eligible NPC takes priority over higher-priority catalog candidates.
  During an issued attack, the old physical target/recovery remains owned until
  genuine recovery; your new choice is queued rather than faking an acknowledgement.
- Repeat attacks use the canonical Runner/class router. On death/Remove or fresh
  FULL departure, ordinary catalog selection resumes after fresh verification and
  settlement. Unknown areas remain HOLD, not a global/legacy mob fallback.
- An explicitly selected unlisted NPC has **one room-local entity exception**;
  no catalog is learned, and no other unlisted NPC becomes eligible.
- Absent, ambiguous, or excluded selection holds offense instead of silently
  attacking an alternative. Select another exact current ID to replace the hold.
  Same exact-species duplicates use deterministic lowest numeric ID.
- Players, room-player identities, loyal/vendor/mount/corpse metadata, guards,
  reviewed protected names and mounts/rocs stay excluded. Unknown/extra metadata
  is not positive NPC proof: manual exception requires exact `attrib="m"`.
- Restricted encounter/room-review areas (including Fengard, Tiyen, and restricted
  Xaanhal matches) remain HOLD for manual exceptions, even with a private preset;
  use their existing reviewed ordinary encounter selector. Manual selection is
  not permission to bypass encounter or private room guards. Explicit visit NO wins.
- Scope includes room, area, character and observed class session/life. OFF,
  death, disconnect, room/area change, entity name/metadata drift or removal
  revoke selection. A changed private preset also revokes it.
- Stale/malformed lists cannot authorize an attack. Recovery uses the existing
  bounded IH owner and later prompt; no new periodic query loop is introduced.
- Only existing `t` / `cv2 target` / GUI controller calls are wired. In-game or
  third-party/global target changes do not have a verified event contract and
  are **not guessed** from GMCP or global variables.

## Validation

`tests/manual_target_tests.lua` runs the actual 49-module bootstrap with synthetic
Mudlet/native callback bridges and fake sends. It is offline evidence, not native
or live combat qualification. Never run this fixture inside connected Mudlet.

From the candidate root:

```sh
lua tests/manual_target_tests.lua "$PWD/combat_v2/"
lua tests/integrated_area_tests.lua "$PWD/combat_v2/"
```

Run both again using the permanent Lua 5.1 executable listed in the delivery
README. This host has Lua 5.4.4 at `/bin/lua`, **not** `/bin/lua5.4`.
All 49 Lua source modules were also compiled with `loadfile` under both runtimes.
The unchanged integrated-area fixture includes the WALK route/consent control.

Existing generic legacy/bootstrap fixtures are not universally green in BASE49.
The full side-by-side results and exact failures are in the delivery directory's
`regression-results.json`; no passing baseline fixture was allowed to regress.
