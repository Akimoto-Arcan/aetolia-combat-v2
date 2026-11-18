# Backend controls and evidence

Combat V2 is a Monk-specific engine. It is not an all-class system or a finished unattended PvP bot. The GUI consumes real state; it does not generate observations. Reload/startup always starts attacks OFF and never issues an attack by itself.

## Bashing

    t <name or NPC id>
    cv2 bash
    cv2 off

Optional explicit queue:

    cv2 queue add 12345
    cv2 queue add 67890
    cv2 queue list
    cv2 bash
    cv2 queue next
    cv2 queue clear

BASH stays armed until you choose OFF or another mode. With no current target, it takes the first queued target. Confirmed kills advance the explicit queue first. Once that queue is exhausted, IH continues hunting living NPCs with the same exact display name as the last confirmed target (for example, the remaining medium pulsating spiders). Confirmed killed IDs, corpses (`d`) and protected/loyal NPCs (`x`) are excluded. Manual retargeting clears the remembered NPC type. After explicit/remembered targets, the selector can choose another name from the imported AC2.2 active mob whitelist. This includes all five Teshen types, so a reaver can advance to a worker. Empty rooms keep BASH armed and checking IH every two seconds; the previous three-miss OFF behavior has been removed. `next` explicitly skips to the next entry. Room item GMCP, when supplied, associates numeric IDs with names. If room GMCP is unavailable, an own-kill line within two seconds of this engine's single-target attack may bind an otherwise unnamed numeric target to its victim name; this is bounded action correlation, not a server-provided ID. No auto-picking of players, neutrals, or unknown objects; no automatic walking. Room changes invalidate the old target and player snapshot, then automatically check the new room without turning BASH OFF. An unconfirmed target disappearance pauses for IH rather than assuming a kill.

The bashing opening is `combo TARGET scs spp spp` whenever Scorpion is not confirmed. After a Scorpion stance message or GMCP confirmation, the normal combo is `combo TARGET sdk spp spp`. Stance is not assumed merely because a command was sent. Explicitly observed shield/rebounding still takes defensive precedence. No PvP limb tracking runs in BASH.

## IH presence checks and recovery

BASH explicitly requests `Char.Items.Room ""` over GMCP immediately before each `ih`, then waits for a fresh room-object result. Aetolia flushes the requested list with the ensuing prompt; plain IH in an unchanged room may produce only text, so it is not sufficient by itself. The adapters follow the legacy Aetolia profile's `Info Here` header (`You can see the following N objects:` / `There is nothing here.`) and `Char.Items.List` room data. A cached room list or a header alone does not prove a target is present. Eligible targets must be selected/queued, remembered, or an exact name from `mobs.lua` (1,046 unique active AC2.2 names). Monster classification is required; dead, loyal/protected, and guard-named NPCs are rejected at selection and execution. There is no random NPC/player targeting.

When a target is unavailable, removed, or missing from a fresh room list, attacks pause and IH recovery begins. The first IH is immediate; additional checks are two seconds apart. A target found on any check resumes normal balance-gated bashing. Failed or unanswered checks retry every two seconds while permission is safe. Manual STOP and mode changes cancel the scan. Room movement cancels the old scan and starts a fresh room check; disconnect/death pause without clearing armed BASH. Reload deliberately starts OFF. Late/canceled callbacks cannot restart an old scan. Ordinary low-health/balance pauses do not trigger an IH spam loop.

`cv2 ih` explicitly starts a fresh presence check while BASH is active. Retry progress is visible in Executor status and `cv2 trace`. PvP does not issue NPC IH checks.

## Area and player permission (checked again by the executor)

The engine reads the real server `AREAS` table. Only exact area names in that list are automatic hunting areas. Entering an unlisted area keeps BASH armed but pauses attacks and shows clickable **Enable here / Keep paused** controls; `cv2 area yes|no` is the command alternative. Approval applies only to that area visit. Moving to another area invalidates old prompts/approval. `cv2 areas` refreshes the server list. Unknown/missing area data fails closed. Approving a town does NOT bypass guard or loyal-NPC exclusions.

Current occupancy comes from `gmcp.Room.Players`, `AddPlayer`, and `RemovePlayer`. A new room must have a fresh full player snapshot (a read-only LOOK is requested if necessary). The character themself is ignored. Other players block attacks unless every one is confirmed in a fresh, solicited server `WEB MEMBERS` roster. Web membership is NOT inferred from web chat or hardcoded player names. Roster requests refresh at two-second intervals when company is present, and stale/missing/invalid rosters block group attacks. Unknown visitors pause immediately; leaving/rejoining and roster changes trigger fresh verification before resuming. `cv2 config group_web off` selects strict solo behavior, `on` restores the authorized web exemption, and `cv2 web` requests a roster. These queries never turn attacks on from OFF.

## PvP and assist

    t Opponent
    cv2 route legs
    cv2 pvp
    cv2 off

`pvp` and `auto` select FULL_AUTO. Routes: legs, arms, head, torso, balanced. ASSIST uses the same selector but requires `cv2 approve` or the APPROVE button. Pending approval is invalidated when the target or resulting action changes.

The selector avoids high-confidence, recently observed parry, falls back to an alternate legal limb, and waits instead of blindly hitting when no legal limb exists. It uses different documented Tekura strikes for legs, arms, torso, and head. Observed shield selects Scythekick. Rebounding currently pauses rather than guessing a bypass.

Conditional routes:

- Prone + mangled head: AXK.
- Prone + crippled limb: BBT. This is a backbreaker progression, not a claimed instant kill on the first throw.
- Both arms broken: TNK.
- Observed injured leg without prone: SWK setup.

Only server text/GMCP observations or explicit corrections change enemy state. A sent attack is never proof that damage landed. First-person attack headers are correlated with a subsequent limb connection, within a short time/line window and the same target generation. Misses, parry, expired contexts, unknown hit sides and other actors do not add trauma. After a confirmed connection, the default estimator adds legacy calibrated trauma with confidence 0.65; the GUI prefixes it with `~`. These numbers are estimates, not current mechanical certainty. They never automatically set crippled/broken/mangled markers.

    cv2 config estimate_trauma off
    cv2 config estimate_trauma on
    cv2 config kick_trauma 8.99
    cv2 config punch_trauma 5.49
    cv2 config boost_kick_trauma 10.8
    cv2 config boost_punch_trauma 6.6

Boosted legacy values apply only to an observed Tiger/Cobra stance. Change calibration only from controlled measurements. An exact manual `track limb` correction replaces the estimated total.

## Monk subprompt

The game prompt is replaced in place with a colored two-line prompt modeled on Fallout's `prompt_sub`. The first line shows HP/mana and available endurance, willpower and XP data; the second shows stance, Kai, balance/equilibrium, each arm, posture/mount state, and current execution mode. The sidebar also shows a prominent STANCE label. Confirmed stance is green, explicit no-stance red, and missing/offline information amber UNKNOWN. Sending an attack never establishes a stance. The original server prompt is replaced only after receipt; GMCP and BaseUI processing remain intact. Display refreshes send no game commands. `cv2 help` or the HELP button opens a reusable, movable, scrollable native help window with grouped command reference; it never changes combat modes or executes attacks. GUI-only hot reload preserves the execution mode, and full bootstrap reload replaces the old prompt trigger rather than duplicating it.

## Review and correction controls

    cv2 track limb ll 25
    cv2 track damage ll 7.5
    cv2 track crippled ll on
    cv2 track broken ra on
    cv2 track mangled head on
    cv2 track aff paralysis on
    cv2 track aff paralysis off
    cv2 track prone on
    cv2 track parry right_leg
    cv2 track parry none
    cv2 track shield on
    cv2 track shield off
    cv2 track rebounding on
    cv2 track rebounding off

Limb aliases: la, ra, ll, rl; full underscore names, head, torso also work. Tracking applies only to the selected target and is cleared on target switch. Evidence records source, confidence, time and target generation. BASH ignores PvP limb/affliction tracking.

Integrations can call `combat_v2_observe({kind=...,target=...,source=...,confidence=..., ...})` or raise the `combat_v2.observation` event `(kind,target,key,value,confidence)`. Boolean flags must be real Lua booleans, not strings. An integration with delayed observations should include the target generation in the direct API. Do not infer enemy afflictions from your own GMCP affliction feed.

## Safety and diagnostics

    cv2 config health_pause 30
    cv2 config health_resume 60
    cv2 config ack_timeout 8
    cv2 config parry_ttl 8
    cv2 config parry_min_confidence 0.75
    cv2 status
    cv2 trace 20
    cv2 reset

Attacks pause below the configured health percentage and resume only above the higher recovery threshold. Dead, disconnected, prone, paralysed or sleeping players do not attack. Each action has its own balance requirements; a kick-only action does not unnecessarily require both arm balances. A sent attack requires observed balance loss and recovery before another send.

For BASH, an acknowledgement timeout/sender failure latches a safe pause without clearing the selected mode; inspect trace and explicitly use `cv2 reset` before retrying an uncertain attack. Disconnect/death prohibit sending while leaving BASH armed. Other modes retain their stop behavior. The watchdog NEVER releases waiting and blindly resends. `Char.Vitals` is event-driven, not a heartbeat: an old vitals timestamp while connected and idle is diagnostic only and must not demand a reconnect. Session login evidence, positive HP, balances, IH target checks, and acknowledgement timeout still gate execution. `reset` is an explicit manual wait reset; inspect trace before using it. Trace is a bounded 100-entry memory buffer, not an uploaded game log. Config changes are session-local (survive code reload in the same profile session, not guaranteed across restart).

    cv2 curing on
    cv2 curing off

FIRSTAID is separate from attack OFF. Its existing server priorities remain unchanged.

## Automatic enemy injury and posture tracking

Confirmed named cripple/break/mangle messages and Discern observations update the matching limb flags and canonical enemy-affliction entries together. Observed incapacitating arm/leg breaks also establish crippled state. Confirmed knockdowns set both prone/fallen affliction aliases; stand/kipup or confirmed posture cures clear both without magically curing a limb. The existing selector then advances to Sweep for an injured standing target, and BBT when crippled and prone are both observed. Prone plus observed mangled head still selects Axe Kick. Markers are not manufactured from estimated trauma or sent commands. Other-target lines are rejected, and BASH still excludes PvP limb tracking.

The actual training-dummy messages `buckles to the ground with a shuddering fall` and `lifts itself upright from the ground` now update posture. Those lines alone do not prove a cripple. The observed dummy test emitted falls/stands but no named limb-cripple confirmations; a live opponent's confirmed injury messages are needed to validate the complete BBT progression in game. Supported generic injury templates were sourced from AC2.2 Kaido / Third Party Salve attacks; further unseen messages should be captured and replay-tested rather than guessed.

## Mounted Monk preparation

Live AB HORSEMANSHIP QUICKDISMOUNTING confirms `QUICKDISMOUNT` / `QDMOUNT` is known and dismounts without losing balance. The tested sequence is two commands: `quickdismount`, then `scs` (or the selected PvP stance). `quickdismount scorpion` and `dismount scs` did not enter a stance; the latter used2s balance. A bare stance command while mounted was rejected. Do not treat an ignored extra argument as successful combined stancing.

GMCP `Char.Vitals.mounted` is0 when unmounted and a positive mount ID when mounted. Normalize this separately from ordinary0/1 balance flags; never compare it only to1. Retain the mount ID separately for diagnostics, not automatic mounting.

Mounted BASH/FULL_AUTO selection first requests quickdismount. Only an observed unmounted state releases its wait; then BASH enters Scorpion or PvP enters the configured preparation stance before continuing. Quickdismount sends do not claim attack evidence. Preserve the original unmounted BASH combo opening. The physical executor also rejects bypassed attacks/stances while mounted, and mental offense is gated while mounted. OFF/SHADOW do not send; ASSIST still requires explicit approval. Stop/mode/target changes invalidate temporary stance preparation. No server queue is left behind.

This was tested with self-only mount/dismount/stance actions and replayed through the actual runner with fake attacks; no live attack was required to validate preparation.

## Enemy-affliction force reset

Use the enemy-panel `RESET` button or `cv2 enemy reset` to clear tracked enemy afflictions plus linked cripple/break/mangle/prone state, active restoration and Sweep setup. Remove the corresponding affliction evidence and pending ASSIST action so an old BBT cannot survive the correction. Keep selected target/generation, numeric trauma, parry/shield/rebounding, own afflictions and actual physical recovery wait intact. Return the enemy list to page1 and refresh immediately. This is a local tracking correction, not a server cure or a promise that the target has no afflictions. New observations may populate it again. It sends no game command and does not tick/restart offense by itself.

## Self-survival governor and native curing

`defense.lua` is a separate self-defense layer, run before mental and physical offense and also bound to the physical executor so manual approval cannot bypass its hold. It ingests explicit OWN affliction gains, discoveries, cures and transformations plus normalized GMCP. Opponent/reporter speech is not self-state. FIRSTAID's `unable to eat/apply/smoke` and `tree locked` messages are diagnostics only, not proof of their cause or proof of a cure.

During BASH/FULL_AUTO, confirmed anorexia, asthma, slickness, paralysis, paresis and impatience receive one native `FIRSTAID ELEVATE <aff>` request per affliction episode. Elevations are temporary until cured; base priorities and curesets are not overwritten. Native FIRSTAID still chooses and executes actual cures. No guessed herb commands, duplicated tree/focus spam, or blind cure balance timers are used. These elevation requests are not confirmation that the server cured anything.

Confirmed anorexia+asthma+slickness holds offense regardless of HP. Low HP pauses at45%, with resumption at65%; prone also holds. These settings do not stop the opponent or guarantee escape from an existing hard lock. Blackout leaves a35% maximum-mana reserve, and automatic Kai Cripple reserves20 Kai beyond its40 cost. Emergency Kai Heal, Transmute, Numbness and other class recovery require live AB/ownership/cost/restriction verification and are not auto-enabled. The observed loss had Kai0; no ability or resource is inferred from class alone.

Commands:

- `cv2 defense status`: show defensive phase, blocked native channels and proposals.
- `cv2 defense audit`: request FIRSTAID settings/priorities/elevations, defences and Monk ability references; no attacks.
- `cv2 defense setup`: explicit operator action, stops attacks and requests a conservative native healing/stand/wake/focus/tree baseline plus health-over-mana preference and the native slickness pill option. The latter requests opiate instead of yarrow, avoiding the smoking requirement but not bypassing an eating block. Does not reset priorities/curesets; requests FIRSTAID readback and remains unconfirmed until checked. Refuses offline.
- `cv2 defense on|off`: enable/disable blocker-elevation/lock governor; does not disable native FIRSTAID.
- `cv2 config defense_health_pause 45`, `defense_health_resume 65`, `defense_mana_reserve 35`, `defense_kai_reserve 20`: tune survival thresholds/reserves. Resume must exceed pause.

OFF/SHADOW/ASSIST do not automatically send defensive elevation requests. Explicit audit/setup are separate commands. Reload and disconnect do not trigger setup. A failed defensive sender latches a hold until operator `cv2 reset` after review. Tests replay the native blocked-channel loss sequence, verify own/other actor separation and prevent offense during a confirmed lock. Offline tests cannot establish survival in a new live spar.

Mechanics/syntax reference: https://www.aetolia.com/game-help/?what=first-aid. Its ELEVATE facility avoids permanently changing the player's base cure order. Current character configuration must be audited online before changing priorities or validating a complete lock-break strategy.

## Training-room match termination

The training room can defeat/reset the character without ordinary death text. The observed sequence was 9% HP, enemy Bladefire Retribution, reporting-dummy victory, `The dummy's eyes dim as it ceases fighting.`, then full HP/mana. Full restored vitals do not prove the character won or never lost.

Either the scoped reporting-dummy victory or the exact dummy shutdown message latches match termination. All modes, including persistent BASH, stop; pending automated mental sends are blocked and the owned mindlock/channel is ceased. The subsequent full-heal reset does not restart attacks. Explicit user mode selection is required to re-arm, and reporting-proxy scope must be enabled again if needed. This is distinct from declaring the character dead. Mental attacks also respect the low-health pause/hysteresis used by the physical runner. This safety fix does not establish a complete defensive/cure-lock strategy.

## Concurrent mindlock and automatic PvP stances

In FULL_AUTO, `mental.lua` acquires Mind Lock against the selected player currently present while physical attacks continue independently. Observed start/progress/success/ejection messages drive lock state; an unrelated or unknown existing lock never permits a targetless Blackout. Target changes revoke trust and cease the previous channel before acquiring the new target. Pending acquisition is not retried every combo. OFF/SHADOW/ASSIST/BASH never automatically send mental attacks. OFF stops automation, not an already-running server lock; use the game `MIND CEASE` command to end that explicitly.

After confirmed lock, Blackout waits for full physical readiness, EQ, sufficient mana and its 25-second cooldown. Its real EQ loss/recovery is tracked independently from physical balance. Explicit balance/EQ rejection cancels the pending-cast wait, preventing a phantom-recovery stall. Kai Cripple can punish an observed restoration window when trance, at least 40 Kai and readiness permit; no resource is manufactured. Controls: `cv2 config mindlock on|off` and `cv2 config kaido on|off`.

Default PvP preparation is Eagle and confirmed cripple+prone BBT setup selects Cobra. BASH retains Scorpion. Controls: `cv2 config pvp_stance eagle|dragon|cobra|tiger|wolf|scorpion|manual` and `cv2 config finish_stance cobra|manual` (other supported stances are also accepted). Stance changes are real executor actions and require observed stance confirmation and recovery. Eagle is intrinsically free per live AB; other free changes require the observed bodily-control acknowledgement. Cobra emits two kicks without punches. While an observed restoration window is active, selection avoids that limb until the estimated window ends. These transitions do not constitute a guaranteed kill against an actively curing opponent.

## Scoped training telemetry and sweep-loop prevention

`cv2 config training_reports on` explicitly binds the reporting runed target dummy to the currently selected target generation and room; `off` disables it. A reporting dummy must be present. This is a training-only adapter, not permission to treat arbitrary speech as combat truth. Target changes, room movement and disconnect invalidate the scope. Exact reported damage totals replace estimates, including reductions after healing. Reported affliction gains/cures update the same canonical flags and enemy-affliction list used by the selector.

Observed restoration application records the limb and a legacy estimated 4.1-second completion window in TARGET / ACTION. Applying poultice does not instantly clear injuries; explicit cure reports clear the corresponding flags. Exact subsequent training totals reconcile unreported damage reductions. The shown damage remains the last observed/reported total, not a claim of continuous server visibility between reports. The restore timer alone never fabricates a confirmed cure.

Sweep is attempted once per confirmed leg-cripple setup. If the target stands before attack balance returns, the selector resumes limb preparation instead of repeating Sweep indefinitely. A newly confirmed cripple after a cure rearms setup; confirmed prone plus cripple still enables BBT. Live controlled tests verified a 34.50% break, 40.00% combo total, subsequent broken/crippled cure reports clearing both flags, and return to combo selection instead of stale Sweep. The training target automatically restores; a complete live BBT lock is not claimed by these tests.

## Target aliases in training tests

A target such as `t dummy` can differ from the server's full attack name (`a battered training dummy`). At an own supported Tekura attack header, the tracker can bind that display name only when this engine sent an attack in the same target generation within two seconds and a unique living, unprotected room NPC matches the alias as a bounded word. Ambiguous aliases fail closed; choose the exact NPC ID instead. Global player matching remains exact. Connections still require a compatible, unexpired hit context, and displayed percentages remain confidence-tagged estimates. Hitpoint `Damage Dealt` is not a limb percentage. Historical missed hits are not backfilled, especially after a dummy resets.

## Sources and remaining verification

Command syntax and static predicates were checked against https://wiki.aetolia.com/Tekura; live AB text is authoritative. FIRSTAID syntax: https://www.aetolia.com/game-help/?what=firstaid. GMCP reference: https://www.aetolia.com/game-help/?what=gmcp.

Combat-text adapters were ported selectively from the user's Fallout autosave and AC2.2 package: independent arm/leg/eq recovery, target-scoped Discern gain/cure, Sweep/stand/Kipup, named shield/rebounding changes, selected-target slain/corpse retrieval, target-missing responses, own Tekura attack + connection, parry and miss. Original files stay local and were not uploaded. Standing does not automatically cure limb markers. Duplicate kill messages cannot advance a queued mob that has not been attacked.

Legacy source locations:
- Aetolia/current/autosave.xml: Balances/Gained, Combat/Enemy Affliction Tracking, Combat/Monk/Monk Limb damage tracking, Combat/Enemy Defenses.
- Aetolia/mpkg/AC2.2.mpackage, member AC2.2.xml: Msys/Offensive Tracker/Monk/Tekura, Msys/Bashing, Stance bash.

The replay suites use explicitly synthetic fixtures based on those real message templates and fake senders. Passing them proves code behavior, not that every server combat message has been captured. Unseen combat lines, precise damage calibration, restoration timing, illusions/hidden information and additional Kaido/Telepathy kill routes remain incomplete. Test in a controlled fight before relying on autonomous PvP.
