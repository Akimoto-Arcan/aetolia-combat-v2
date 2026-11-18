# Source-backed defense coverage

## Safety and ownership

This code-only audit maps every deduplicated Fallout source key. It contains no
account export, character inventory, live resources, personal ranks or private
profile paths. Legacy literals and exact own gain/loss triggers were inspected;
only current AB-verified commands were added. Old help without current ownership
is not a learned ability. A source key is not itself permission to send.

- FIRSTAID exclusively owns these **12** generic defenses: courage, density,
  fangbarrier, insomnia, levitation, rebounding, waterbreathing, instawake, arcane,
  harmony, speed and vigor. Actual server requests for blindness, deafness,
  insulation, temperance and venom_resistance all returned
  `You may not set such a defence.` They have no native configuration control.
- Current game mechanics override the old Fallout mandatory-self-affliction
  assumption. Blindness/deafness are read-only **SELF-AFFLICTED** legacy PvP
  tactics, with `NEEDS CURRENT MECHANIC PROOF` availability reasons. Neither is
  wanted by default or auto-maintained. No client EAT/OUTC/cache loop, cure-policy
  write, baseline seed API or restoration transaction ships. Their native cure
  priorities remain the operator's concern and are never changed here.
- Current Tattoos MINDSEYE is **one-time protection against a blind/deaf attack**,
  NOT vision while blind. A protected amaurosis attempt consumed Mindseye without
  establishing blindness. Current Telepathy Clairvoyance is minor mental offense,
  not a verified vision prerequisite. No automatic self-affliction is approved.
- Mindseye is the required usable protection: wanted by default, but TOUCH remains
  gated on fresh charged TATTOOS evidence, actual own UP and post-ACK ready prompt.
  Its current own activation/EQ recovery was verified by the parent. Startup and
  reload MASTER stay OFF; default wanted does not authorize sends or grant ink.
- Insulation, temperance and venom resistance remain UNAVAILABLE pending current
  usable resource/command proof; no old frost/antivenin commands are guessed.
- Correcting the native catalog invalidates old confirmation. A fresh complete
  unique 25-row transaction plus footer is required. Pending uncertainty,
  conflicting-ACK fencing and last-active restoration memory are retained.
- The client catalog has 33 entries: courage is native-owned, Recognition is
  passive, and the remaining 31 are capability-gated executable preparations.
  There is one skill owner for deathsight/thirdeye, not duplicate curative pills.
- Knowledge is scoped to curated Kaido, Telepathy, Survival, Vision and Avoidance
  entries. Telesense accepts either verified skill group but has one executor.
  Nightsight uses Vision. Group inference never grants tattoo ink or artifacts.
  Precise ability Lists beat cached rank inference. Class/session changes revoke
  capabilities; reload does not treat cached Groups/List as fresh evidence.
- Cloak and Mindseye TOUCH controls require fresh own TATTOOS evidence, parsed at
  its header and committed at the next real prompt. Charged activations decrement
  the local conservative budget before dispatch. Report transactions are version
  fenced against intervening tattoo events/debits; reports opened or completed
  during unresolved TOUCH consumption cannot replenish ink. External own
  activations revoke uncorrelated charge authorization until a fresh report;
  multiple own ACK lines do not double-debit a committed TOUCH. Fresh reports
  replace/revoke ownership. Passive active tattoos stay visible through unrelated
  DEF List absence, but explicit newer removal defeats old ACTIVE evidence (and
  an in-flight older report). A newer valid report may prove ACTIVE again.
  Charge maps and session authorization are never persisted.
- Immunity uses IMMUNITY and the canonical kaido_immunity alias. The old
  kai_immunity spelling is an alias, not a separate executable defense. Its
  120-second cooldown starts at dispatch/confirmed activation, never at venom
  consumption. Unknown prior cooldown waits a conservative full 120 seconds from
  the first fresh complete defense snapshot; repeated snapshots do not extend it. Repeated DEF snapshots do not extend the activation clock.
  Generic balance/ability rejection text has no action identity and cannot
  release a committed cast or roll back its cooldown, before or after own UP.
  Confirmation plus a genuine subsequent ready prompt, or an explicit reviewed
  reset, is still required. Unknown replies and unconfirmed sends remain
  fail-closed; timeout never manufactures recovery.
- MIND CLOAK ON/OFF is distinct from tattoo TOUCH CLOAK and MIND INSIGHT ON/OFF.
  DODGE ALL and DIVERT ALL are separate currently verified commands, not guessed
  MELEE syntax. No unsupported cancellation command is invented.
- Clarity is conservatively withheld while *any* unresolved affliction is present
  until the complete current antipsychotic tree can be source-enumerated. This is
  deliberately stricter than the skill's antipsychotic-only restriction.
- Fresh Char.Vitals blind/deaf 0/1, own Afflictions positives/Add/Remove and exact
  own DEF events are ingested. Cached Vitals ticks cannot replay old positives
  after a newer strip. Fresh positive Vitals survive Defences List absence.
  Raw DEF text stays positive-only and its footer never replays older rows.
- Every new drain and other optional skill/tattoo is opt-in. Immunity and the
  required, fresh-ink-gated Mindseye protection are wanted by default. MASTER, sequence and pending actions are never
  restored from preferences; startup/reload stays OFF. GUI opening is read-only.
  Explicit self-defense controls are allowed while offense stays SHADOW; they never
  switch offense mode, start BASH, authorize movement or arm GLOBE.

## UI and remaining validation

The existing 14-slot manager, paging, ALL/MONK/FIRSTAID/ACTIVE filters and geometry
remain. MONK includes client skill/tattoo owners, which are labeled SKILL/TATTOO.
Rows distinguish required, wanted, actual and capability reason. PASSIVE,
UNAVAILABLE, UNKNOWN and NOT LEARNED do not offer a fake activation toggle. Native
unknown-priority actions fail validation. OFF, full-resource and loss/activation
cooldown metadata survive backend row projection. No combat footer, GLOBE control,
floating BaseUI/chat layout or affliction-card geometry was changed.

Shield remains manual/emergency read-only rather than automated constant upkeep;
Guarding remains manual limb policy. Fitness and Recursion are not currently
owned; Numbness and HOLD BREATH are excluded hazards. Artifact/racial/ylem buffs
remain unavailable/unknown without proof; flight and mounted actions cannot move
the character from this defense controller. Offensive/cure/resource tattoos do
not become persistent defense loops.

Before activation, keep MASTER OFF until review and fresh capability/native/ink
readback. Mindseye is one-time protection, not a blind-vision prerequisite; do not
self-blind/deaf as a BASH experiment. Class skill and tattoo controls retain their
learned/ink and physical recovery gates. No curative owner is enabled or shipped.
`python3 tests/run.py` already includes `tests/curative_defenses.lua` in its test
manifest. It may also be run directly with
`lua tests/curative_defenses.lua "$PWD/combat_v2/"` for current-mechanic safety and
the independently reproduced rejection, tattoo-budget and passive-status orderings.
The parent restored the original native blindness/deafness cure settings after the
manual probe; no private baseline priorities or live stock counts are embedded. A native Immunity-specific cooldown rejection
line has not been supplied: its precise own reply still needs source verification
and an exact regression fixture, rather than an invented message. Until then an
unrecognized rejection follows the existing retained uncertainty barrier. No live
action, deployment, Git operation, priority change or hunting upgrade is part of
this release. Newly added optional drains are not automatically armed.

## Complete source-key disposition

Programmatically deduplicated: **304** source rows. **189 excluded**, **6 passive**, **36 supported**, **73 unknown**.

SUPPORTED means implementation coverage, not live ownership or armed state.
PASSIVE is read-only capability/status coverage. EXCLUDED is a deliberate safety
or class restriction. UNKNOWN has no activation path pending current evidence.

| Source key | Disposition | Reason |
|---|---|---|
| `alertness` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `allsight` | SUPPORTED | Alias of Mindseye one-time sensory protection, not vision while blind. Fresh charged ink gates TOUCH. |
| `ameliorate` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `angel_empathy` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `angel_here` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `arcaneskin` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `armour` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `attuning` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `aura` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `auresae_symbol` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `axe_avert` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `axe_obstruct` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `axe_rampage` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `axe_repel` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `balancing` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `barkskin` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `battlechant` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `berserk` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `berserking` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `bladefury` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `blindness` | UNKNOWN | Legacy self-afflicted PvP tactic; no verified safe BASH use/vision mechanic. No native defense or client pill owner. |
| `bliss` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `blissed` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `blood_thirst` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `bloodsense` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `bloodshield` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `bloodtrails` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `bloodwisp` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `blue_mist` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `blurred` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `blurring` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `boar` | PASSIVE | Read-only learned ability or freshly reported active tattoo; no activation loop. |
| `bodyheat` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `boneshaking` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `boosting` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `bracing` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `brutality` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `bruteforce` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `canopy` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `catabolism` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `celerity` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `chameleon` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `chaosorb` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `chariot` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `clarity` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `cleansing` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `cloak` | SUPPORTED | Fresh charged-ink capability; opt-in TOUCH only. |
| `cloaked` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `coagulation` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `concealed` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `concentrate` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `concentration` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `consciousness` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `constitution` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `cornering` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `corpus_warding` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `countercurrent` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `damariel_symbol` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `dauntless` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `deafness` | UNKNOWN | Legacy self-afflicted PvP tactic; no verified safe BASH use/vision mechanic. No native defense or client pill owner. |
| `deathaura` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `deathsight` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `density` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `devil` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `devilpact` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `dilation` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `discharge` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `disperse` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `disregarding` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `disunion` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `diverting` | SUPPORTED | Alias of divertmelee. Curated skill owner; fresh per-group ownership and observed recovery required. |
| `divertmelee` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `divine_speed` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `dodgemelee` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `eagleeye` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `earthenform` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `earthsense` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `eclipse` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `elongated` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `endurance` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `entwine` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `ethereal` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `ethne_symbol` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `fangbarrier` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `fearless` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `featherstep` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `fetching` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `finesse` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `fireblock` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `firefist` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `firefly` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `fireveil` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `fitness` | EXCLUDED | Absent from current owned Kaido List; deprecated help is not ownership. |
| `fitnesse` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `fleetfoot` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `flexibility` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `focalmark` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `foreststride` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `forestwalker` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `fortify` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `fury` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `fury_brace` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `galeward` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `ghosted` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `gravechill` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `green_mist` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `greenfoot` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `gripping` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `harden` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `hardening` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `hardiness` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `haste` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `healing` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `heatsight` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `herculeanrage` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `hidden` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `hide` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `hiding` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `hierophant` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `illusion` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `imbue_erosion` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `imbue_stonefury` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `imbue_will` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `immunity` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `inscribe` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `insight` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `insomnia` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `inspiration_constitution` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `inspiration_dexterity` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `inspiration_intelligence` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `inspiration_strength` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `instawake` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `insulation` | UNKNOWN | Native defense ownership rejected; current usable manual resource/command unverified. No sender. |
| `invert` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `ironskin` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `kai_recursion` | EXCLUDED | Absent from current owned Kaido List; incompatible with Trance and drops Kai. |
| `levitating` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `levitation` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `life_scent` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `life_vision` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lifebloom` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lifesap` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lifescent` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lifevision` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lightform` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lightshield` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `linked` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lipread` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lipreading` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `litheness` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `lycanthrope` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `mace` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `magicresist` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `maingauche` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `mask_scent` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `masked_scent` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `masqueraded` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `mass` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `metabolism` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `metabolize` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `miasma` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `might` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `mindcloak` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `mindseye` | SUPPORTED | One-time blind/deaf protection. Required wanted default; fresh charged ink, own activation and real EQ recovery gate TOUCH. |
| `mindspark` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `missiles` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `missles` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `mist_blue` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `mist_green` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `mist_red` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `mist_white` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `mist_yellow` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `momentum` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `moon` | PASSIVE | Read-only learned ability or freshly reported active tattoo; no activation loop. |
| `morisensus` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `moss` | PASSIVE | Read-only learned ability or freshly reported active tattoo; no activation loop. |
| `mountain` | PASSIVE | Read-only learned ability or freshly reported active tattoo; no activation loop. |
| `mounted` | EXCLUDED | Manual movement/mount policy; no automatic movement. |
| `naturaltide` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `nightsight` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `nightstalk` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `numbness` | EXCLUDED | Deferred-damage hazard; no unattended automation. |
| `oath_forestwalker` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `overgrowth` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `owl` | PASSIVE | Read-only learned ability or freshly reported active tattoo; no activation loop. |
| `pacing` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `palming` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `parry` | EXCLUDED | Manual limb/Guarding policy; not automatic upkeep. |
| `parryleft` | EXCLUDED | Manual limb/Guarding policy; not automatic upkeep. |
| `parryright` | EXCLUDED | Manual limb/Guarding policy; not automatic upkeep. |
| `pestilence` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `phase` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `potence` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `prefang` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `protection` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `putrefaction` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `quicken` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `quietus` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `rebirth` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `rebounding` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `reckless` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `recognition` | PASSIVE | Read-only learned ability or freshly reported active tattoo; no activation loop. |
| `red_mist` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `reflection` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `regeneration` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `regenerations` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `reprieve` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `resistance` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `resonance` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `resurgence` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `retracted` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `returning` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `ricochet` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `safeguard` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `sagacity` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `saliva` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `salivating` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `sand_conceal` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `sanguispect` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `screen` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `selfishness` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `shadow` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shadow_devour` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shadow_engulf` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shadow_mantle` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shadowblow` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shadowsight` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shadowslip` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shaman_spiritsight` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `shaman_warding` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shielded` | EXCLUDED | Manual/emergency shield only; attacking breaks it, no upkeep loop. |
| `shine` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shroud` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `shrouded` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `simultaneity` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `skywatch` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `snarling` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soul_fortify` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soul_fracture` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soul_harvest` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soul_mask` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soul_substitute` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soul_thirst` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soulcage` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soulmask` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `soulthirst` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `speed` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `spheres` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `spiritbond` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `spiritsight` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `splint` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `splitting` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `stalled` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `stalwart` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `stance` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `stealth` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `stonebind` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `stonefury` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `stoneskin` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `sublimation` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `sun` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `suncloak` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `surefooted` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `survive` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `swagger` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `symbol` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `targetleft` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `targetright` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `targetting` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `telesense` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `temperance` | UNKNOWN | Native defense ownership rejected; current usable manual resource/command unverified. No sender. |
| `tempering` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `thickfur` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `thickhide` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `thirdeye` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `thorncoat` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `toughness` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `trepidation` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `truth` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `twinsoul` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `veil` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `vengeance` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `venom_resistance` | UNKNOWN | Native defense ownership rejected; current usable manual resource/command unverified. No sender. |
| `vigor` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `vitality` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `ward` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `warding` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `warmth` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `waterbreathing` | SUPPORTED | FIRSTAID sole owner; full native priority snapshot required. |
| `waterward` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `weathering` | SUPPORTED | Curated skill owner; fresh per-group ownership and observed recovery required. |
| `weaving` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `werebear` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `wereboar` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `werecroc` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `wereraven` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `werewolf` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `white_mist` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `wisp_anxiety` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `wisp_stigmata` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `wrath` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `yellow_mist` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
| `zenith` | EXCLUDED | Other-class/source-only entry; no current Monk activation ownership. |
| `zephyr` | UNKNOWN | Current ability, ownership, source identity or safe command not verified; no sender. |
