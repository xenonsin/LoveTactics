# Deployment, the field, and the bench

You bring **four**. You field **four**. *Which* four is decided at the Gate, before the stair
(`Descent.party`); *where they stand* is decided at the start of every battle — on the board, with the
enemy already on it. Once the bell rings nothing changes hands: there is no way back onto the field
mid-fight.

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
   excluded, so the phase never offers a cell that is already taken. A body is excluded by its whole
   **footprint**: an ogre is a 2×2 block, and marking only the corner it is anchored on left the other
   three lit for the player to stand a knight inside.

`Combat.deployUnit` refuses such a tile as well, returning `nil` for ground that is off the board,
unwalkable, or somebody else's — judged over the footprint of the body being stood up. Every caller
already reads that `nil` as *there is no room there*, so the rule holds for the phase, for its
auto-fill, and for the walk-off path that skips the phase entirely.

Bottom is the party's edge everywhere in `models/arena.lua` — enemies muster on the low rows, the
draft's marching grid faces them — so a board that wants the party entering from elsewhere authors its
own zone rather than being guessed at.

**A board cut out of the map authors its own, and it is a band rather than a block.** `Arena.fromGrid`
hands over the whole width of the edge the company arrived from, two rows deep, because that is what the
fixed block becomes once the board has an outside: you came in *there*, so *there* is where you line up.

**And on a cut board those two rows are whatever the map put there**, which is the one thing a rolled
board never had to worry about. A window can clear both fightability floors and still be walled along
the single edge the company happened to approach by. Measured across 180 seated fights: **a quarter
offered fewer than eight of the sixteen band tiles, and four offered none at all** — at which point the
zone falls back to the spawn spill, and what the player sees is five lit tiles scattered down a wall
with the company smeared over them. That is what the phase looks like when the seating rule has failed,
and it is the only place in the game where that failure is visible at all.

So the band **deepens** rather than the zone giving up: it takes another row of your own side until it
holds `DEPLOY_MIN`, capped at half the board, past which "your side" has stopped meaning anything and
the fallback is the honest answer. Every claim the zone makes survives — the edge you arrived from,
continuous with where you walked in — and the only thing given up is the fixed depth, which was a shape
and never a promise. With the shape floor on the seating passes ahead of it
([docs/overworld.md](overworld.md)), the share offering under half a band is now 3%, and none are empty.

If that yields fewer than `Arena.DEPLOY_MIN = 4` tiles (the field cap, mirrored the way
`Combat.MAX_FIELD` mirrors `Player.MAX_FIELD`), it falls back to the authored spawns: a cramped board
must never produce a phase with nowhere to stand.

The zone is **one geometry with three uses** — placement at the bell, rotation mid-fight, and where a
reinforcement walks on — and it is lit with one overlay (`BattleMap:drawDeployZone`) in the party's
blue, deliberately the same grammar as the enemy muster telegraph in its red. Same statement,
different owner.

### Rally ground — removed

The deploy zone used to stay on the board after the bell as **rally ground**: one quiet outline along
its edge, drawn only while somebody was on the bench, with a **Rally Ground** box in the tooltip
column teaching the Fall Back move. Both are gone with the move (`Combat.rallyGround`,
`Combat.rallyTileInfo`, `BattleMap:drawRallyGround`). Nothing marks the zone once the fight starts,
because nothing can happen there.

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
- The phase's controls stack down the **left column**, in the band the fight's own drawer entries
  occupy (`battle.deployControlRect`) — the screen's furniture goes where the screen already keeps it,
  and the strip's foot is left to the hint line alone. Above them stand the only two pieces of the
  fight's drawer that mean anything before the bell — **Settings** and the **board-turn pair** — and
  they stand *open*: there is no hamburger on this screen, because a fold over two always-legal
  controls hides nothing and costs a click on the beat where turning the board is the first thing a
  player wants to do. The drawer returns with the fight. The controls read top to bottom in the
  order the decisions are made in: **Loadout**, **Auto-Fill**, **Clear**, **Auto**, and the bell last.
- **Auto-Fill** places the four who fought last battle (`Player.lastDeployed`, ids only — no tiles are
  ever persisted) on the board's own bound spawns: exactly where they would have stood before there was
  a phase to choose in. **Clear** empties the board. **Begin Battle** commits.
- **Loadout** (`I`, pad `X`) opens the Armory's own screen (`ui/panels/party.lua`) over the phase, on
  the same roster and stash the hub and the overworld edit. Gear is the other half of the question this
  phase asks: where a body should stand is answered against what it is carrying, and until this button
  the last chance to move an item was a leg of overworld ago — before the player had seen the ground,
  the enemy line or the objective. The company standing right now is badged on the panel's rail
  (`fielded`). Closing it re-reads what gear decides for everyone placed (`Combat.restampDeployed`:
  initiative is the average speed of a body's ability items, snapshotted when it was stood up). Nobody
  is moved, and nothing is rebuilt — a re-placed body would knit back in through the summon shader, and
  nobody arrived. A fight with no player behind it (a probe, a debug board) has no stash, so no button.
- **Auto** (directly above the bell; `V`, pad `Y`) decides whether the fight opens played or
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

**Nothing comes back off it.** There were two ways onto the field mid-fight and both are removed:

- **Fall Back** — a living unit standing on rally ground spent its turn to trade places with a reserve.
- **Reinforce** — a slot opened by a death was filled free, and a *last-stand override* let you send
  one in past the cap with nothing of yours left standing.

They came out when the expedition became four. An expedition is four (`Descent.PARTY_MAX`) and the
board holds four (`Combat.MAX_FIELD`), so there is never a body waiting to be sent for, and a control
that can never be legal is deleted rather than left drawing greyed.

**One rule had to invert with them.** `Combat.eliminated` used to count the bench: a party with
somebody benched had *not* lost, because a reserve could still be called. With no way to reach them
that becomes a battle you can neither win nor lose — the turn loop has nobody to hand the turn to and
nothing to resolve on, which is worse than either ending. It reads `aliveCount == 0` now.

`Combat.reinforceTiles` **stays**, under a name that outlives its move: it is what `ui/deploy_phase.lua`
and `models/encounter_battle.lua` lay the *opening* line out with, which is the job it was always
really doing. `combat.bench` stays too — an arena still parks anybody it had no room to seat, and
`Combat.benchCount` still reports it. What changed is that nothing brings them back.

## One derived rule

**HP, mana and cooldowns live on the character instance, not the unit table.** That was what made a
body able to leave the board and come back as an arrival — the turn-scoped bookkeeping (tallies, anchor
tile, tempo debt) resets, the durable state does not. Nothing returns mid-fight any more, but the split
is unchanged and still the reason a body carries its wounds out of one battle and into the next.

## Defeat

One line, in `Combat.outcomeFor`:

```lua
if Combat.eliminated(combat, side) then return "loss" end
```

`Combat.eliminated` is *nothing standing*, full stop — `aliveCount(combat, side) == 0`. It used to also
ask whether the side had a reserve to send in, which is the rule that inverted when the two ways back
onto the field came out (see [The bench](#the-bench)). Every other side always read it this way, since
only the party ever had a bench.

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
| `models/combat.lua` | `deferOpen` / `Combat.openBattle`, `deployUnit`, `undeployUnit`, `restampDeployed`, and what is left of the bench section (`benchUnit`, `reinforceTiles`, `fieldCount`, `benchCount`, `eliminated`) |
| `ui/deploy_phase.lua` | the phase: the strip, the drag, the placement, the column's control stack |
| `ui/panels/party.lua` | the Loadout screen the phase opens (`fielded` badges the standing line) |
| `ui/battle_map.lua` | `drawDeployZone` (the phase) |
| `ui/combat_panel.lua` | the panel's layout, built and checked by `tests/combat_panel_spec.lua` |
| `states/battle.lua` | `gutterRect`, `deployControlRect`, `commitDeploy`, `openDeployPhase`, `openDeployLoadout` |
| `tests/deploy_spec.lua`, `tests/bench_spec.lua` | the rules above, headless |
