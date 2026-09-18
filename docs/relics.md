# Relics — parked, and what became of them

**Status: PARKED 2026-09-17.** Nothing in a run grants a relic. The system is still on disk and still
loads; what was cut is every route to one. This document is the record of what was parked, what the
25 surviving effects became, and what a revert would have to put back.

Read this before citing `models/relic.lua` as live behaviour. Its header carries the same banner, but
the ~700 lines under it describe the shelf as it was *built*, not as it is *reachable* — and a parked
system decays into prose that reads exactly like a live one.

## What a relic was

A roguelike boon, found on an expedition and carried **only for that run**. Where gear, prestige and
the roster persist at the hub, relics were the within-run power the game was missing: pick up a dozen
across a descent and the company reaching the bottom is not the company that left the city.

One shelf, three rungs, and each rung a different *kind* of thing rather than a different size:

| rung | what it was | count |
|---|---|---|
| common | a **gift** — a flat always-on number, no strings | 18 |
| uncommon | a **trade** — a real gain at the price of a real loss | 10 |
| rare | an **inversion** — a rule of the game rewritten | 8 |

Everything was always on, everything stacked, and a magnitude resolved as `base + (n-1) * step`.

## Why it was parked

The shelf's effects were re-premised as ordinary **items**. The argument is a scope one: a relic was
held by the *run* and felt by the *whole company*, and almost every one of them reads better as a
thing one body wears.

The Rooted Oath is the clearest case. As a relic it rooted the company — which made every escort and
control-point objective unsatisfiable, and the honest answer in its own header was that the relic
would have to be *refused* on those maps. One rooted body among four is not a broken objective; it is
a gun emplacement, and where you set it down at deployment is the decision.

## The mapping

**Eleven were cut**, not converted: the pure-stat commons, one per stat, each a flat number for the
whole company with no strings. A `+1 damage` that every body gets for free is what an item shelf
already sells a hundred of, and a second copy of it is not a decision.

> Deep Draught · Early Bell · Full Skin · Long Lesson · Overfull Flask · Quiet Ward · Second Breath ·
> Struck Sigil · Thumbed Die · Weight of Plate · Whetstone Tithe

`tests/item_rules_spec.lua` asserts their **absence** as items, so a deletion whose blueprints are
still sitting in `data/relics/` awaiting a revert cannot quietly grow back.

**Twenty-five became items.** Every one keeps its name, its effect and its magnitude, and changes
scope from the company to the bearer.

| relic | item | what carries it now |
|---|---|---|
| The Deep Larder | `utility_deep_larder` | `encounterCleared` hook |
| Duelist's Spur | `utility_duelists_spur` | `openingBoon` |
| Glutton's Purse | `utility_gluttons_purse` | `encounterCleared` + `maxBonus` |
| Honed Edge | `utility_honed_edge` | `openingBoon` |
| The Kept Vigil | `utility_kept_vigil` | `openingBoon` + `encounterCleared` |
| The Long Watch | `utility_long_watch` | `openingBoon` |
| Warding Icon | `utility_warding_icon` | `openingBoon` |
| The Bared Head | `utility_bared_head` | `maxBonus` |
| The Bared Nerve | `utility_bared_nerve` | `bonus` |
| The Braced Stance | `armor_braced_stance` | `bonus` |
| The Far Mark | `utility_far_mark` | `rules` |
| The Keen Edge | `utility_keen_edge` | `bonus` |
| The Overreach | `utility_overreach` | `bonus` + `rules` |
| The Quick Draw | `utility_quick_draw` | `bonus` + `rules` |
| Rank and File | `utility_closed_ranks` **(renamed)** | `traits` |
| The Standing Order | `utility_held_line` **(renamed)** | `traits` |
| The Thin Blade | `utility_thin_blade` | `bonus` + `maxBonus` |
| The Held Breath | `utility_held_breath` | `rules` |
| The Long Wait | `utility_long_wait` | `rules` |
| The Open Wound | `utility_open_wound` | `rules` |
| The Overdraft | `utility_overdraft` | `rules` |
| The Rooted Oath | `utility_rooted_oath` | `rules` |
| The Unpaid Tithe | `utility_unpaid_tithe` | `rules` |
| The Whetted Vow | `utility_whetted_vow` | `rules` |
| The Yoked Company | `utility_yoked_company` | `rules` |

### Three things the conversion changed on purpose

**Two names moved, because both were already taken.** `utility_rank_and_file` is Pride's creature kit
— unpriced, `noSteal`, pinned by `tests/pride_circle_spec.lua` as *"nothing here is for sale"* — and
it already carries this trait. `utility_standing_order` is the artificer's signature and shares
nothing with the relic but the words. Both new names are **provisional and mine rather than the
author's**; each blueprint's header says so.

**Glutton's Purse pays its cost differently.** The relic drained 4 stamina from everyone at the
opening bell, through a `battleStart` hook an item does not have. Inventing that seam for one
blueprint would have been a mechanic built for one caller, so the toll is a lowered stamina *ceiling*
instead — the same quantity, in the existing vocabulary, felt every fight.

**The Yoked Company is still collective, and that is structural.** A shared health pool cannot be
scoped to one body without ceasing to be the thing it is. One body wears the yoke and all four share
the bar; its description says so, and `Combat.applyUnitRules` splits the collective half from the
per-bearer half explicitly. It is the single documented exception to the bearer rule.

## What the conversion added to the engine

Three seams, none of which existed before, each the smallest thing that would carry its half:

- **`item.rules`** — the rare tier's inversions, per bearer. Names live on `Item.RULE_NAMES`, the
  merge policy on `Item.mergeRules` (`damageMultiplier` multiplies, everything else is first-wins —
  the parked shelf's own rule/magnitude split, kept term for term so the live path and the revert
  path cannot disagree). Folded to `unit.rules` by `Combat.applyUnitPassives`.
- **`item.openingBoon`** — statuses the bearer opens a fight in, applied by `states/battle.lua`. Read
  off the grid rather than queued by a run, so it works in **every** fight however it was entered —
  campaign, descent, arena, draft — which the relic could not.
- **`item.encounterCleared`** — `models/item_hook.lua`, the deliberately smaller twin of
  `Relic.dispatch`: one event, no per-item scratch, no stacking ladder.

All three must also be copied onto the instance in `Item.instantiate`, which is where they were first
forgotten: every consumer is handed live items off a grid, never blueprints, so a field left off that
list parses, ships, and silently does nothing.

### And one thing it exposed

**The grader could not see any of it.** `Grade.of` scored all 25 at a confident `0.0`, and its
"blind" flag — the thing that distinguishes *this instrument cannot read it* from *this is worth
nothing* — only ever fired for items with an `activeAbility`. A passive whose mechanism is a rule
rewrite was therefore graded zero and would have been recut to tier 1. Two fixes, both in
`models/grade.lua`: the blind test now covers the three new seams, and an **authored `grade`** (in
turns) wins outright, exactly as it already did for a status and a trait. Every converted item
carries one, because the instrument reads net stat swing and a trade is net zero by construction.

## What is parked, and how to lift it

A reachability cut, not a deletion. `models/relic.lua`, all 36 blueprints in `data/relics/`, the four
UI modules and both specs are untouched and still load — `tests/relic_spec.lua` and
`tests/relic_rules_spec.lua` still drive the real model, so a revert is proved green before it is
reachable.

| what | where | to lift |
|---|---|---|
| the Reliquary, the Sin's Altar, the Weeping Stone | their blueprints in `data/encounters/` | clear `parked = true` |
| the floor's guarantee of two of them | `guaranteeKinds` in `models/descent.lua` | restore the struck entries |
| the Merchant's relic shelf | `states/game.lua` | restore the slate loop |
| the Crossroads' relic stake | `states/game.lua`, `models/crossroads.lua` | restore `grantRelic` and repoint its eight dilemmas back off `grantSealed` |
| the Rest's Sharpen verb | `states/game.lua`, `ui/panels/rest_choice.lua` | pass `onSharpen` again; the row is already conditional |
| the relic tray | `states/game.lua` | restore the `RelicStrip.draw` call |

The combat fold is deliberately **left wired**: `unit.relicBonus` is simply never populated, so it
costs nothing standing and is the half a revert would otherwise have to rebuild.

Two things do **not** come back by lifting the flags, and both are deliberate:

- the **eleven pure-stat relics** would return to the drop pool alongside the items their siblings
  became, which is the duplication the cut existed to remove;
- a camp could mint Honed Edge again while the item of that name is also on the floors.

`Relic.PARKED` is a declaration the call sites read, never a switch inside the module — parking a
system by gutting its model leaves the tests asserting against the parked behaviour, which is how a
parked system quietly becomes unrevertable.
