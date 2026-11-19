# Passive supply ledger

`combat_v2/ledger.lua` is pure Lua (5.1-compatible syntax), with **no commands, senders, queries, timers, network calls or action-authorizing proof**. Its only storage is `c.supply_ledger_data`. It neither reads nor changes the older `c.containers_data` helper, including its timeout quarantine and unresolved refill barriers. Automatic refill can remain blocked while passive observations continue.

## Integration API

```lua
local L = dofile(moduleDirectory .. '/ledger.lua')
L.cache(c, key, absoluteCount, source, observationTime) -- trusted FC/IC inputs
local event = L.text(c, nativeReceivedLine)
if event and event.cache then
  -- Feed through the parent stock recorder, which calls L.cache once.
  S.stock(c, event.cache.key, event.cache.count, event.cache.source)
end
L.prompt(c)       -- actual server prompt, not an arbitrary output line
local view = L.state(c) -- deep-copy read-only presentation snapshot
L.invalidate(c)  -- disconnect: retain observations/counters, revoke confidence
```

The stock recorder owns authoritative reserve ingestion. `text` returns an optional `{cache={key,count,source}}` event for an accepted native absolute reserve receipt; it does **not** call the stock recorder or recursively mutate reserves. Other text updates are internal only. Feed fresh GMCP Rift Change events to the parent's recorder as **absolute** IC totals, never deltas; do not replay cached GMCP on attachment. FC keys are `health`, etc.; IC keys are `ic:anabiotic`, etc. Counts must be bounded nonnegative integers, including strict digit strings. A confirmed zero survives failed parsing and unrelated use; only a new trusted absolute observation can replace it.

The parent owns startup/manual baselines, hooks, display and lifecycle. This module never initiates the full FC, IC, vial, pipe and bandage observations it needs. Attach it only to trusted native received-line hooks, not a chat/proposal aggregator. Anchored parsing rejects quoted/prefixed speech and command proposals, but a raw native-looking string has no cryptographic provenance.

## Snapshot fields

- `cache[key]`: independent reserve `{count,source,at,observed_at,estimated=false,confidence}`.
- `carried.vial[type]`, `.pipe[type]`, `.bandage[type]`, `.pill[type]`: aggregate `{count,baseline,used,received,deposited,delta,baseline_used,baseline_delta,at,observed_at,event_at,estimated,confidence,uncertain,unverified_pattern}` as applicable. Absent `count` means **unknown**, not zero. `used` and `received` are session counters; `delta` is net observed carried change. `deposited` records transfers back into IC. `baseline_delta`/`baseline_used` locate the latest native baseline within those counters.
- `used[key]`: session confirmed-use counters (FC fluid name, smoking herb name, or namespaced IC pill key). Refreshing a baseline never resets them.
- `refills[fluid]`: observed doses transferred from FC to carried contents, not number of refill actions.
- `sources[kind]`: last complete native `rows[id]`, baseline `at`, historical `complete`, and current `confidence`. Per-ID row counts/descriptions/decay/light state remain native baseline metadata; aggregate usage/refill never fabricates a consuming/refilled ID.
- `issues`: sorted baseline, malformed/incomplete/disconnected confidence, missing/depleted coverage and individual expiry issues. Missing-type coverage is assessed only after a complete kind baseline.
- `complete`: all three kinds have a historically complete baseline. **Not freshness, certainty, connection proof or action permission.** `pending`: bounded native list or refill correlation is staged. Top-level `estimated=true` identifies the view as a passive ledger. No `completefresh=true` or helper capability is produced.

A health baseline of 17 + 50 sips is 67 carried. One drink makes the aggregate 66, leaving both per-ID native counts unchanged. A subsequent proven 50-dose infusion makes carried 116. Its following native `900 sips remaining` sets FC health to **900 absolute**, independently; it must not subtract another 50. A pill receipt increments session use without decrementing IC reserves. `remove 1 ... total ... 1862` sets the IC reserve to 1862 and records one received carried pill; a subsequent identical absolute GMCP total does not charge it again. Without a pill baseline, carried pill count stays unknown even though received/used/delta are known.

## Accepted evidence and conservative boundaries

Actually observed native receipt fixtures:

```text
You take a drink of an elixir of health from a plain wooden vial.
You take a drink of an elixir of vigor from an academy vial.
You swallow an anabiotic pill.
You remove 1 anabiotic, bringing the total in the cache to 1862.
You store 455 anabiotic, bringing the total to 503.
You infuse a plain wooden vial with 50 doses of an elixir of health from your fluidcache.
You have 900 sips remaining in your fluidcache.
```

The FC pair requires an allowlisted native fluid description and known wooden/academy vial wording, within the same prompt, at most three clock seconds and six subsequent received lines. Unknown/malformed infusion, a second infusion before the remaining line, malformed totals, expired context and uncorrelated remaining totals cannot change FC. Multiple transfers still update carried aggregate independently when their individual receipts are valid. Ambiguous FC context clears at a prompt; no permanent parser latch exists. FC pair source is `native FC refill`; IC sources are `native IC withdrawal` / `native IC deposit`.

Exact descriptions include `a purgative concoction` and `an elixir of the arcane`. Unknown fluids never become guessed health or other inventory. Strict inherited smoke/press forms are available as estimates, explicitly marked `unverified_pattern=true` until their real native wording has been observed; offline fixture matching does not validate their game mechanics. No guessed bandage refill receipt is enabled.

Native lists use whitespace-collapsed exact headers:

```text
Vial Elixir Sips Decay
Pipe Herb Puffs Decay Lit
Bandage Poultice Presses Decay
```

Rows require at least two spaces between native columns, correct `vial`/`pipe`/`bandage` numeric IDs, unsigned integer counts/decay (or artifact `A`), and exact pipe `Yes`/`No`. Header, opening separator, unique valid rows, closing separator **and actual prompt** are required. Lists are bounded by 15 seconds, 512 received lines, 32-character IDs and 2048-character input lines. Malformed, duplicated, incomplete, late or mid-use frames preserve the prior baseline and do not resurrect old contents. A failed kind does not block other kinds or receipt counters, and a subsequent complete frame can restore confidence. Unsolicited complete native frames are passive observations only; they cannot release the older helper's uncorrelated-response quarantine.

Stock confidence does not expire merely because time passes. Uses reduce known aggregates to a floor of zero; exceeding the observed amount sets `uncertain=true`, while session counters keep advancing. Unobserved transfers, destruction or unsupported wording can make any passive aggregate incomplete. Native refresh is the reconciliation path, not a claim of exact perpetual inventory.

Expiry ages independently from each per-ID `observed_at` in real days (`86400` seconds). Every duplicate below five days warns, even if a replacement is healthy; exactly five does not. Artifact `A` never expires. Refill does not renew expiry. Snapshot generation never rewrites observation timestamps. Clock precedence is `c.supplies_clock`, `c.containers_clock`, `os.time`.

## Offline verification

Run **only in a separate normal Lua process**, never in a connected Mudlet interpreter:

```sh
luac -p combat_v2/ledger.lua
luac -p tests/ledger.lua
lua tests/ledger.lua
```

The suite exercises observed receipt fixtures, duplicate aggregation, paired FC transfer/absolute/zero, IC absolute plus GMCP, unknown pill inventory, strict rejection, correlation budgets, malformed/late frames, midframe use, independent-kind recovery, exhaustion, expiry, disconnect, unchanged helper quarantine and unchanged combat object identities. There is no live game validation or deployment in this module's offline tests. Parent integration/installer tests are separate.
