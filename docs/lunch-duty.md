# Explicit one-session globe and cache duty

`lunch.lua` is a deterministic native controller; it does not call an AI API.
Loading the module and `attach(c)` do not authorize gameplay. An explicit current
Monk/BASH grant in the recorded return room is required by `start()`.

For this authorized duty the return room is 55290, the low threshold is strictly
below 200, and refill targets are 1500 health sips and 2000 anabiotic pills.
It finishes the current fight without starting another, waits for genuine action
recovery, then borrows the existing PT controller for the directory/shop/return
trip. FIRSTAID stays independent. It never buys globes, uses bank/org funds,
changes class, resets cure priorities, or enables the held hunting walker.

Directory, WARES, cache and carried-gold evidence must agree before purchase.
Unknown formats and uncertain purchases stop with their barriers retained; they
are never purchase-retry authority. Health uses direct fluidcache refills.
Anabiotic requires an explicit singular-pill WARES row, INCALL, a newer absolute
cache observation and exact wallet readback. Native anabiotic WARES framing has
not yet been captured: synthetic tests are not native validation. An unsupported
live format stops before purchase.

Return resumes only in the exact recorded room with authoritative empty player
occupancy, preserving trip-time upkeep intent. The existing globe owner handles
initial summoning and all recovery. Pool inventory is refreshed on re-enable;
charges still require the native probe response. Proven exhaustion of all owned
globes ends duty at a resolved gap. A single generic-globe error is not proof that
all globes are exhausted.

`lunch_boot.lua` binds mode, explicit convenience-request and automatic-recall
guards. Explicit operator OFF cancels duty even if already OFF. An owned route
may borrow only its exact recorded PT destination; an owned resume may request
BASH only in its proper phase. Unknown transaction leases continue blocking
competing actions after cancellation. Balance-free mount FOLLOW remains separate.

Inspect `c.lunch_duty` and `c.lunch_controller` for status. Normal reload/reconnect
must never grant a new AFK session; a fresh explicit authorization is required.
Do not replace a busy owner. Keep native checks to real observations: all
behavioral suites run in separate Lua processes, never inside connected Mudlet.
No survival guarantee is implied.
