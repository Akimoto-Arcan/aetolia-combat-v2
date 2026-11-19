# Remaining refill recovery and Archivist activation

## Outcome

Offline inspection found **no proven replacement container-authority protocol** and **no captured active-Archivist resource protocol**. No new sender, parser, provider module or deployment is justified. Keep the existing query quarantine unchanged, passive ledgers independent, native fluidcache last-use refill intact, and all fourteen Archivist class rows tracking-only/default OFF. A new parser accepting invented resource fixtures would not improve capability.

## Custom refill: real blocker, not an expired timer

`containers.lua` deliberately quarantines anonymous list responses after timeout/uncertain transport. `audit` rejects quarantine; ordinary commit both grants per-ID authority and can settle resource barriers. Do not reuse commit for a passive/recovery observation. The parent's supplied current state is query quarantine `response timeout` and no committed refill barrier; absence of a resource barrier does not cure query provenance.

Reviewed alternatives:

- A HELP nonce echoes its own topic, not the identity of a container snapshot. An older asynchronous EMPTY table can arrive between valid new HELP boundaries. TCP ordering, prompt receipt, quiet intervals, a new observer, a new local generation and a full fresh-looking baseline do not distinguish that history.
- Current source uses `Char.Items.Room`/`Char.Items.List` for item identity and occupancy. Neither source nor inspected native captures establishes a per-container fluid/herb count, lit/decay record, snapshot request ID or causal completion contract. Inventory IDs/attributes are not doses. Do not invent `Char.Items` fields or an undocumented `Core.Ping` ordering guarantee.
- Native FC infusion receipts establish aggregate carried transfers and absolute corresponding cache totals, not a particular container's emptiness or future fill eligibility. Fresh `IRE.Rift.Change` establishes IC reserve absolutes only. Neither replaces per-ID authorization.
- `PROBE <known-container-id>` is a documented read-only inspection path, but the inspected evidence supplies decay information, not a correlated complete empty/type/reserve transaction. An item-specific name is still not a request-generation witness if old same-ID answers can be delayed.

**Release requirement:** a documented server-bound snapshot identity/completion protocol, or server-maintainer confirmation of causal draining of all earlier list work plus exclusive outgoing-list observation. Obtain the actual guarantee before implementing a framed controller. The existing `container-recovery-design` report/matrix remains conditional design, not working recovery. No automatic reconnect/reset is authorized; even a new socket would not settle an unknown prior action.

### Bounded read-only queries the parent can make now

These are native documented commands, not new aliases or invented endpoints:

| Query | What it can establish | What it cannot authorize |
|---|---|---|
| `HELP FLUIDCACHE`, `HELP REFILLS`, `HELP BANDAGES` | Current native refill mechanics/syntax | Correlation or quarantine recovery |
| `VIALLIST`, `PIPELIST`, full `BANDAGELIST` | Passive observed per-ID rows/uses/lit/decay | Fresh helper authority on the quarantined stream |
| `FLUIDCACHE`, full `IC` | Passive reserve observations | Drain of delayed container replies |
| `PROBE <already-known container ID>` | That item's native description/decay details | A new safe action from an anonymous old reply |

These queries are optional targeted evidence collection, **not a batch to repeat**. Route container observations through the existing passive audit/ledger path; do not set helper versions/freshness or clear quarantine. Native automatic vial/bandage refill already handles last use while reserves exist. Pipes still have no proven custom recovery here. Ask server maintainers specifically whether list computations can emit after a later command's final prompt, or whether a supported correlated per-container resource response exists; no such command was located offline.

## Archivist: documented discovery commands were located

The private native prerequisite capture explicitly documents:

- `AB BIOESSENCE ENERGY` -> `BIO ENERGY`, a **read-only energy report**. Energy starts at three under the documented mechanic, but that is **not current available energy**. Consumed energy returns after a documented 20 seconds per; expended energy remains occupied until its associated effect expires. Never manufacture availability from a timer/default.
- `AB NUMEROLOGY PRIMALITY` -> `NUMBERS`, a **read-only report of currently contemplated numbers**. `CONTEMPLATE <number>` changes state and is **not** a permitted inspection command. Duality/Triunity describe capacity, not the current contemplated set.
- Public AB access works while inactive. `BIO ENERGY`/`NUMBERS` may reject the current Monk; a rejection is useful evidence of inactivity, not reason to change class. The parent may query their read-only output now, but cannot obtain active-Archivist capability merely from accessible help or guild membership.

Legacy code references `gmcp.Char.Vitals.bio` for energy. This is a useful **candidate field name only**, not a verified current active-class payload. No observed active-class range, zero/update/removal lifecycle or current contemplated-number GMCP schema was located. Do not add a public setter or substitute fabricated events for those observations.

### Verified active producers versus still-missing authorization

These six rows are active-ability implementation gaps, **not intrinsically passive effects**:

| Canonical DEF | Captured public syntax | Required proof/policy |
|---|---|---|
| `ameliorate` | `BIO AMELIORATE [OFF]` | Expends 1 energy; endurance drain; opt-in and owned activation/recovery |
| `ethereal` | `BIO ETHEREAL [target]` | Consumes 2 energy; short diminishing mitigation; explicit emergency policy, not permanent upkeep |
| `linked` | `ELICIT LINK <0-50%>` | Yi, Jherza, Jhako; explicit chosen percentage and mana reserve; 0 disables, never silently default to 50 |
| `oneness` | `ELICIT ONENESS [END]` | Yuef; mana/willpower drain; opt-in, cancellation and confirmation |
| `sublimation` | `ELICIT SUBLIMATION [target]` | Yuef, Rafic, Yi; self/target identity and owned acknowledgement |
| `veiled` | `ELICIT VEIL` | Rafic, Yuef; movement invalidation and opt-in |

Public AB/DEF facts identify producers; they do not authorize casting. Preserve manual hazards for the other eight client-owned Archivist rows; native FIRSTAID remains sole owner of Speed and the other eleven native defenses. Keep Vision voice Recognition separate from canonical Bioessence `recognition`.

### Concrete future provider boundary (specification, not implemented API)

When an independently authorized active-Archivist session supplies real evidence, a resource provider should expose read-only `snapshot()` and `invalidate(reason)` operations, with no gameplay sender. Its snapshot must preserve source/native witness, session/class epoch, receive sequence, observation time, available energy and the exact currently contemplated set; unknown fields remain unknown. The adapter must validate the observed grammar/schema, not accept caller-asserted `verified=true` or infer numbers from learned ranks.

The existing buff controller must still require fresh actual `Char.Status.class == Archivist`, class-scoped learned ability, current native resource evidence, explicit wanted/master/drain/percentage policy, ordinary readiness and **all** pending resource/transport barriers at selection **and dispatch**. Reserve cost before sending; ambiguous outcomes retain commitments. Revoke resource capability on class/session change without deleting committed actions. Active-class known ownership alone, cancellation requests and poisoned former-class caches cannot bypass these gates. No module is staged until the real report format and lifecycle make this boundary implementable.

## Evidence and verification

Inspected local sources: `combat_v2/containers.lua`, supplies/ledger and item-handling references; `docs/defense-coverage.md`; the prior container-recovery design; private `defense-toggle-audit/matrix.json`; native toggle audit and Archivist prerequisite/ability/DEF captures. `archivist-prerequisites-and-filters.json` has `BIO ENERGY` syntax at array index 19 and `NUMBERS` at index 31 (zero-based). The toggle audit itself mostly covers tattoos/Vision; it is not Archivist resource evidence. Only public mechanics are reproduced here; no player inventory/account payloads are included.

Separate-process fake-sender runs on **Lua 5.1.5 and Lua 5.4.4** passed the existing suites `containers` (226), `containers_usage` (119), `containers_integration` (75), `supplies_quiet` (21 plus refill-disabled regression), `ledger` (108), `ledger_integration` (147), and `curative_defenses` (889, explicitly a legacy sensory fixture, not current activation proof). No live/native test ran.

Two additional suites failed in both runtimes in this concurrently edited working tree: `defense_coverage` reports `wrong owner/command boar`; `buffs_integration` reports `active tattoo became phantom missing`. These are reported to the parent/defense owner, not repaired here; they prevent claiming a clean full-suite release. A requested filename `multiclass_defenses.lua` did not exist; actual coverage files were discovered and run instead. Existing source, tests, profile state and manifests were not edited. This new report is the only repository artifact from this investigation.
