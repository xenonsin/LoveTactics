# Deployment, the field, and the bench

You march **everyone**. You field **four**. Which four, and where they stand, is decided at the start
of every battle — on the board, with the enemy already on it — and can be changed mid-fight by rotating
someone off the line and someone else on.

This replaced a persistent *marching grid* arranged once in the hub. Placement is a decision about
**ground** — where the cover is, which flank is open, how far the enemy line is — and none of that
exists until the board does. So it is made where the ground is.

## The two numbers

| Number | Where | What it caps |
| --- | --- | --- |
| `Player.MAX_FIELD = 4` | `models/player.lua` | The **field**: how many stand on the board at once. |
| `Combat.MAX_FIELD = 4` | `models/combat.lua` | The model's own mirror of the above, so combat stays player-free (the same rule `DraftRun.PARTY_MAX` follows). |

**The company is the roster, and it is uncapped.** There is no `MAX_PARTY` and no screen that picks a
subset before an embark: everyone you own comes to the quest, and the only question anyone is ever
asked about who fights is asked over the board. A capped company plus a hub screen to fill it was one
decision too many — you were choosing eight of nine without the board in front of you, and then
choosing four of the eight ten seconds later with it. The second choice is the real one, so it is now
the only one.

Everyone not standing is the **bench** (`combat.bench`), which is the whole point — a reserve you can
spend. It grows with the roster: a late-campaign company benches more than it fields by a wide margin,
and the deployment strip pages sideways rather than shrinking its cards past legibility.

## The deploy zone

`Arena.build` gives every board an `arena.deployZone`: the tiles you may put a body on. Where the map
does not say otherwise it is a **fixed block**, so every board offers the same shape of choice:

1. an authored `deployZone` on a curated layout wins outright — a map that wants to say *you come in
   through this gate* says so, as a list of `{ x, y }` in `data/arenas/<id>.lua`;
2. otherwise, **the eight tiles at the bottom centre of the board** — `Arena.DEPLOY_COLS = 4` wide by
   `Arena.DEPLOY_DEPTH = 2` deep, flush with the party's home edge. Four bodies over eight tiles is a
   real placement, and the two rows are what make front-and-back a decision and not just
   left-and-right. It is deliberately *not* derived from where the spawns landed: the generator spreads
   those across the full board width, which lit the whole bottom of the board and made the zone
   indistinguishable from "your half";
3. tiles the board itself seated somebody on — an escorted survivor, an enemy authored deep — are
   excluded, so the phase never offers a cell that is already taken.

Bottom is the party's edge everywhere in `models/arena.lua` — enemies muster on the low rows, the
draft's marching grid faces them — so a board that wants the party entering from elsewhere authors its
own zone rather than being guessed at.

If that yields fewer than `Arena.DEPLOY_MIN = 4` tiles (the field cap, mirrored the way
`Combat.MAX_FIELD` mirrors `Player.MAX_FIELD`), it falls back to the authored spawns: a cramped board
must never produce a phase with nowhere to stand.

The zone is **one geometry with three uses** — placement at the bell, rotation mid-fight, and where a
reinforcement walks on — and it is lit with one overlay (`BattleMap:drawDeployZone`) in the party's
blue, deliberately the same grammar as the enemy muster telegraph in its red. Same statement,
different owner.

## The phase

`ui/deploy_phase.lua`, hosted by `states/battle.lua`. The board is built and the enemy is standing on
it; the zone is lit; the **company strip** sits in the combat log's rect — the board-width gutter
directly under the tiles, so each portrait is under the ground it is about to be dragged onto. The log
takes its rect back the moment the fight starts.

- **Drag** a card onto a lit tile to deploy. Tile to tile repositions; dropping on an occupied tile
  **swaps** the two; dragging a body back off the board withdraws it to the bench. A drop on illegal
  ground returns the portrait — nothing is lost by a bad drag.
- The strip fits the whole company where it can. Past that, cards stop shrinking (`MIN_CARD_W`) and it
  **pages**: the wheel scrolls it, keyboard/pad navigation drags it along, and a small `<n` / `n>` tab
  at each end counts who is off-screen.
- **Auto-Fill** places the four who fought last battle (`Player.lastDeployed`, ids only — no tiles are
  ever persisted) on the board's own bound spawns: exactly where they would have stood before there was
  a phase to choose in. **Clear** empties the board. **Begin Battle** commits.
- **Auto** (paired flush left of the bell; `V`, pad `Y`) decides whether the fight opens played or
  watched — it is the same `battle.autoAll` flag the in-fight drawer's Auto entry flips, seeded from it
  and handed back on the commit, so the two can never disagree and the setting carries across fights
  like the playback speed does. Armed, the switch and the bell both wear the spotlight gold and the
  bell reads **Begin (Auto)** — a fight that plays itself is not a thing to discover after turn one.
  Any input still takes the current turn straight back (`reclaimAutoTurn`). A tutorial forbids
  auto-battle outright (`autoAllowed`), and there the switch does not draw at all.
- Keyboard and pad reach all of it: the cursor crosses between the strip and the board, confirm picks
  a member up, confirm on a zone tile places them.

Committing is the one path into "the fight is now running" (`commitDeploy`): it resolves the opening
(below), benches whoever was not placed, and calls `Combat.openBattle`.

### Fights that skip it

`deploy = false` in the battle opts. Placement was already decided by whoever set the fight up, and the
arena's bound spawns are the party:

| Caller | Why |
| --- | --- |
| `states/prologue.lua` | Act 0 is hand-placed, and a lesson addresses units by the cell they spawned on. |
| the guided lessons | Same. |
| `models/draft_match.lua` | Draft made that decision in the shop, on its own 4×2 grid. |
| `ui/panels/pvp.lua`, `states/duel_debug.lua` | A duel is a fixed symmetrical board; both peers must build the identical opening position from the seed alone. A build is `Build.TEAM_SIZE = 4` with no bench. |

## The battle opens in two beats

`Combat.new(arena, party, enemies, { deferOpen = true })` builds the board — units, traps, hazards,
walls, props — and **stops**. No passive is applied, no opener fires, the timeline is not rebased. The
phase then stands the company through `Combat.deployUnit`, and `Combat.openBattle` rings the bell
once: rebase, passives, reservations, the stamina refill, incense, `"The battle begins."`, and
`Trait.setup`. It is idempotent, so an opener can never fire twice.

Every other caller passes no `opts` and gets a fully opened battle in one call, exactly as before.

`Combat.deployUnit` is *not* `Combat.addUnit`: a body placed at the opening bell takes its natural
initiative **unclamped** and rides the opener pass. `Combat.addUnit` clamps at 0 and skips the opener,
which is right for a summon, a reinforcement wave, and a rotation — bodies arriving into a fight
already under way.

## The bench

**A benched member is not in `combat.units`.** It is an entry — `{ char, relicTraits, statuses }` — and
nothing more. A benched body wearing a flag would have to be excluded from ~200 `u.alive` reads
(targeting, AoE dedupe, the AI, hazard ticks), and any one missed reads as a ghost you can hit from
across the board. Worse, `Combat.inTimeline` warns what happens to a unit that rides the timeline and
never acts: it pegs the rebase minimum at 0 and **freezes every duration in the battle**.

Two ways onto the field, priced differently because they are different decisions:

### Rotate — costs the turn

A living unit **standing in the deploy zone** spends its turn to trade places with someone on the
bench. The button sits above Wait in the combat panel; it greys out with the reason
(`Combat.canRotate` returns `false, why`) so "fall back to your own lines to rotate" is something you
can act on rather than a dead button.

The incoming body stands on the tile the outgoing one was holding, at the initiative that unit's turn
would have cost (`turnMoveCost + tempoDebt + Combat.ROTATE_COST`). A rotation buys you a different
body, not a free beat.

`Combat.withdraw` mirrors `Combat.dismiss`: the channel breaks, its summons go with it, its ground and
its held bodies are released. It is **not a death** — no `Trait.onDeath`, no `allyDown` tally, no
corpse, nothing to revive. The board and the turn strip fade it out through an `exit` fx cue, silently:
the death knell over somebody standing perfectly well on the bench would be a lie.

### Reinforce — free

A slot has opened (somebody fell), so filling it costs nothing — you already paid, with a body. The
drawer entry lights when `Combat.canReinforce` is true; picking a body then picks a zone tile. The
arrival takes `Combat.addUnit`'s natural-clamped-at-0 slot, so it cannot cut ahead of whoever is acting.

The **last-stand override**: with nothing of yours left standing you may always send one in, even past
the four-body cap. Without it, a field of four fallen bodies would be a defeat with a full bench in
hand — and that body walking on to stand over its own dead is the whole reason the bench exists.

## Two derived rules

**Rotating is not a cleanse.** A withdrawn unit's statuses ride to the bench and come back on re-entry.
They do not tick while off the board, for the plain reason that nothing off the board ticks — so
falling back *parks* a poison rather than curing it.

**HP, mana and cooldowns persist; the unit table does not.** Those live on the character instance.
Coming back builds a new unit around the same `char`, so the turn-scoped bookkeeping (tallies, anchor
tile, tempo debt) resets — correct, since what returns is an arrival.

## Defeat

One line, in `Combat.outcomeFor`:

```lua
if Combat.eliminated(combat, side) then return "loss" end
```

`Combat.eliminated` is *nothing standing **and** nobody left to send in*. Only the party has a bench
(`Combat.benchCount` returns 0 for anyone else), so this reads exactly as it always did for every other
side — and the enemy cannot win by clearing the four in front of them either, since `killAll` asks the
same question.

The UI half is `offerLastStand` in `states/battle.lua`, consulted **before** `Combat.evaluate` in
`resolveAdvance`: when the player's last body falls with a reserve waiting, the bench chooser is raised
instead of the defeat panel. One rule, two surfaces.

## The front line

A `frontRow`-scoped relic (the Martyr's Bell) and Rowan's Vigil both resolve against *the line you
actually put forward* — the deployed units standing nearest the enemy — which does not exist until the
phase commits. `states/game.lua` hands battle a `resolveOpening(deployed, front)` callback instead of
pre-computed traits and boons, and battle calls it at the commit. `models/relic.lua` and
`models/overworld_ability.lua` take the front line as `ctx.frontRow`, falling back to everyone deployed
where no line has formed (a test, a dispatch with no board).

Relic traits are resolved over the **whole company**, bench included: a party-scope relic is worn by
everyone who marched, and a benched member has to arrive already wearing it.

## Where it lives

| File | What |
| --- | --- |
| `models/arena.lua` | `arena.deployZone`, `Arena.DEPLOY_COLS`/`DEPLOY_DEPTH`/`DEPLOY_MIN`, the authored `deployZone` field |
| `models/combat.lua` | `deferOpen` / `Combat.openBattle`, `deployUnit`, `undeployUnit`, the bench section (`benchUnit`, `canRotate`, `rotate`, `withdraw`, `canReinforce`, `reinforceTiles`, `reinforce`, `fieldCount`, `benchCount`, `eliminated`) |
| `ui/deploy_phase.lua` | the phase: the strip, the drag, the placement |
| `ui/panels/bench_chooser.lua` | who comes on, for both routes |
| `ui/battle_map.lua` | `drawDeployZone` |
| `ui/combat_panel.lua` | the Rotate button |
| `states/battle.lua` | `gutterRect`, `commitDeploy`, `openDeployPhase`, `rotateTurn`, `reinforceAt`, `offerLastStand`, the Reinforce drawer entry |
| `tests/deploy_spec.lua`, `tests/bench_spec.lua` | the rules above, headless |
