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

With no current target, BASH takes the first queued target. A confirmed selected-target death advances the explicit queue first. Once that queue is exhausted, IH continues hunting living NPCs with the same exact display name as the last confirmed target (for example, the remaining medium pulsating spiders). Confirmed killed IDs, corpses (`d`) and protected/loyal NPCs (`x`) are excluded. Manual retargeting clears the remembered NPC type. When no eligible matching NPC remains, three two-second IH checks run before halting. `next` explicitly skips to the next entry. Room item GMCP, when supplied, associates numeric IDs with names. If room GMCP is unavailable, an own-kill line within two seconds of this engine's single-target attack may bind an otherwise unnamed numeric target to its victim name; this is bounded action correlation, not a server-provided ID. No auto-picking of players, neutrals, or unknown objects; no automatic walking. A room change stops bashing. An unconfirmed target disappearance pauses for IH rather than assuming a kill.

The bashing opening is `combo TARGET scs spp spp` whenever Scorpion is not confirmed. After a Scorpion stance message or GMCP confirmation, the normal combo is `combo TARGET sdk spp spp`. Stance is not assumed merely because a command was sent. Explicitly observed shield/rebounding still takes defensive precedence. No PvP limb tracking runs in BASH.

## IH presence checks and recovery

BASH explicitly requests `Char.Items.Room ""` over GMCP immediately before each `ih`, then waits for a fresh room-object result. Aetolia flushes the requested list with the ensuing prompt; plain IH in an unchanged room may produce only text, so it is not sufficient by itself. The adapters follow the legacy Aetolia profile's `Info Here` header (`You can see the following N objects:` / `There is nothing here.`) and `Char.Items.List` room data. A cached room list or a header alone does not prove a target is present. Eligible targets must be the selected or explicitly queued NPC, with `m` attributes or a monster icon; no random NPC/player selection.

When a target is unavailable, removed, or missing from a fresh room list, attacks pause and IH recovery begins. The first IH is immediate; additional checks are two seconds apart. A target found on any check resumes normal balance-gated bashing. After three failed checks, BASH switches OFF and cancels the retry timer. An unanswered request also consumes one check after its two-second response window; no response is not treated as confirmed absence. No fourth request is sent. Manual STOP, switching modes, disconnect, room change, player death, and reload cancel the scan; late responses cannot restart it. Ordinary low-health/balance pauses do not trigger an IH spam loop.

`cv2 ih` explicitly starts a fresh presence check while BASH is active. Retry progress is visible in Executor status and `cv2 trace`. PvP does not issue NPC IH checks.

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

The watchdog stops on acknowledgement timeout or a lost session/TCP connection; it NEVER releases waiting and blindly resends. `Char.Vitals` is event-driven, not a heartbeat: an old vitals timestamp while connected and idle is diagnostic only and must not demand a reconnect. Session login evidence, positive HP, balances, IH target checks, and acknowledgement timeout still gate execution. `reset` is an explicit manual wait reset; inspect trace before using it. Trace is a bounded 100-entry memory buffer, not an uploaded game log. Config changes are session-local (survive code reload in the same profile session, not guaranteed across restart).

    cv2 curing on
    cv2 curing off

FIRSTAID is separate from attack OFF. Its existing server priorities remain unchanged.

## Sources and remaining verification

Command syntax and static predicates were checked against https://wiki.aetolia.com/Tekura; live AB text is authoritative. FIRSTAID syntax: https://www.aetolia.com/game-help/?what=firstaid. GMCP reference: https://www.aetolia.com/game-help/?what=gmcp.

Combat-text adapters were ported selectively from the user's Fallout autosave and AC2.2 package: independent arm/leg/eq recovery, target-scoped Discern gain/cure, Sweep/stand/Kipup, named shield/rebounding changes, selected-target slain/corpse retrieval, target-missing responses, own Tekura attack + connection, parry and miss. Original files stay local and were not uploaded. Standing does not automatically cure limb markers. Duplicate kill messages cannot advance a queued mob that has not been attacked.

Legacy source locations:
- Aetolia/current/autosave.xml: Balances/Gained, Combat/Enemy Affliction Tracking, Combat/Monk/Monk Limb damage tracking, Combat/Enemy Defenses.
- Aetolia/mpkg/AC2.2.mpackage, member AC2.2.xml: Msys/Offensive Tracker/Monk/Tekura, Msys/Bashing, Stance bash.

The replay suites use explicitly synthetic fixtures based on those real message templates and fake senders. Passing them proves code behavior, not that every server combat message has been captured. Unseen combat lines, precise damage calibration, restoration timing, illusions/hidden information and additional Kaido/Telepathy kill routes remain incomplete. Test in a controlled fight before relying on autonomous PvP.
