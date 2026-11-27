# Earthcaller Reinforce

Combat V2 can cast `DIRGE REINFORCE` on itself during BASH through the existing survival owner.

## Controls and policy

- Enable defensive automation with `cv2 defense on`.
- Default: heal below 50% HP, never at exactly 50%.
- Existing below-20% and qualified incoming-stall escape priority is preserved.
- `combat_v2.current.config.earthcaller_reinforce_enabled = false` disables this feature.
- `combat_v2.current.config.earthcaller_reinforce_health` sets the runtime threshold (greater than 20 and at most 100).
- OFF revokes new intent. It does not pretend an already-issued action was cancelled.

New BASH intent acquires the native Apocalyptia list and explicit Reinforce Known header when missing. A fresh complete native affliction list is also required. After resetting an already connected Lua profile, a one-off DIAGNOSE may be needed to obtain that server snapshot; DIAGNOSE consumes equilibrium and is not periodically polled.

## Ownership and settlement

The spell requires real current readiness, at least one functional arm, at least 150 absolute fervour and 50 absolute willpower. It shares existing action/resource ownership and uses the existing defense transport, not a second timer or curing system. FIRSTAID remains in charge of ordinary curing.

Settlement requires its own activation and heal narrative, observed fervour debit, EQ consumption/recovery, a real post-activation willpower observation, and a later ready prompt. Net willpower change is not treated as an exact 50-point debit: regeneration and FIRSTAID can share that Vitals frame.

## Live evidence

After fixing the net-WP attribution fault, the supervised run produced 7 native Reinforce activations and 26 kills, gaining 1,172,700 XP. The final recorded heal token was debit-observed, the shared owner was idle, and hunting continued after healing. The heal trigger was temporarily raised to exercise useful healing under ordinary hunting damage, then restored to 50%. No health or GMCP data was fabricated and no injury/death experiment was used.

The run ended OFF at 4,042/4,042 HP with no pending physical/heal transaction. This does not establish unattended safety, natural re-wield recovery, or live below-20% escape acceptance.
