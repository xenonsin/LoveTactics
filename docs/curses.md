# Curses

A **curse** is a hex on one piece of gear. The piece still works — that is what makes it a curse rather
than a rock in your bag — and what it does, it does to whoever is carrying it.

It is the second thing that can be wrong with an item, and it is deliberately the mirror of the first:

| | what it means | where it is undone | what it costs |
|---|---|---|---|
| **broken** | the piece stops working | the Forge | gold, and it is back this minute |
| **cursed** | the piece works *against* you | the Cathedral | trips, or gold to skip them |

`models/curse.lua` is the whole model; `data/curses/<id>.lua` are the blueprints.

## A curse speaks the item's own vocabulary

This is the entire implementation and the reason the feature is small. A curse blueprint declares the
fields an **item** declares, and they are read by the code that already reads them:

| field | folded by | notes |
|---|---|---|
| `bonus` | `Combat.applyUnitPassives` | flat stats, summed into the same total the item's own are |
| `maxBonus` | `Combat.applyUnitPassives` | resource ceilings |
| `resist` | `Combat.applyUnitPassives` | per-tag, pre-mitigation; **negative is a weakness** (`docs/vulnerability.md`) |
| `unarmedBonus` | `Combat.applyUnitPassives` | bare-fist figures |
| `rules` | `Item.mergeRules` → `unit.rules` | the fourteen names on `Item.RULE_NAMES` |
| `traits` | `Trait.attach`, via `Curse.traitsOn` | attached with the **piece** as owner, so `Trait.param` works |
| `openingBoon` | the opening bell, via `Curse.openingBoons` | a status the bearer starts every fight in |

Three things fall out of that for free:

- **No new balance surface.** A curse's −3 defense is the same quantity a coat's +3 is, measured through
  the one subtractive figure `docs/balance.md` is written about.
- **Rule-bending already exists.** `rules` is the parked relic shelf's inversions, now gear's: health
  pinned at 1, no walking at all, mana paid in blood. A hex that makes you pay for spells in blood is one
  line, not a system.
- **One place to look.** An author asking *what may a curse do?* reads `models/item.lua`, which is where
  they were going anyway.

What is **not** borrowed: `price`, `grade`, `unlockLevel`, `class`. A curse is not a thing on a shelf. It is
never bought, sold or found on its own — it arrives attached to something else.

### The one field of its own: `binds`

```lua
binds = true,
```

A binding curse makes `Item.isBound` answer true — the single predicate every mutation path in the game
already refuses through (the grid editor, the stash, the vendor, combat theft, the at-risk sweep). One
field, and the piece cannot be taken off, put down, sold or stolen.

`Item.durabilityMax` deliberately tests the raw `bound` **field** rather than calling `Item.isBound`, so
a signature relic still never wears while a hexed sword still does. A relic is not a thing that breaks;
a curse is not a warranty.

**The bind holds against you, not against the priests.** "It cannot be removed" means *by you,
underground, with your hands*. The rite is the answer, and a curse with no answer would not be a curse —
it would be a deleted item with extra steps.

One consequence worth knowing, because it falls out of the shared flag rather than being decided here:
`Player.atRisk` skips bound items, so **a bound hex is never left on the floor when a company wipes**
(`Descent.dropPack`). The haul goes down with the fallen and this does not. That reads correctly — the
thing you could not put down is still the thing you could not put down — and it means a cursed find
cannot be lost the trip it was found on, only lifted.

## Getting rid of one

`docs/the-count.md` states the law this could most easily have broken:

> A cost on recovery is a tax on **needing** to recover, and needing to recover is what being bad at the
> game looks like.

The Ward's answer to a wound is the answer that survived three attempts, and the Cathedral's rite is that
answer with an item where the body goes:

| | cost | served by |
|---|---|---|
| **the rite** | free, always, no gate and no purse test | the piece stays with the priests for `Curse.RITE_DESCENTS` (2) trips — paid in going down without it |
| **the lifting** | `Curse.fee` in gold | done before you leave the room |

Gold buys **speed** and never relief. A company that cannot pay is never stuck with a hex forever; it is
stuck with it for two trips, and it chose which two. `Curse.RITE_DESCENTS` is the same figure as
`Wound.REST_DESCENTS` on purpose — the city's two free paths cost the same span of the same clock, so a
player learns the unit once.

The rite ticks in `Gate.night`, beside the ward's, because walking into the stair is the one moment a
descent begins. A piece that comes due is handed back **clean and to the stash**, never to the cell it
came off — that cell is two trips stale and the player has almost certainly filled it.

### Why the fee may be authored per curse

The Ward charges one number for every bone, because a bone is a bone. A hex is a thing with a **name**
the player can read off the tooltip before they walk into the room, so a nastier one costing more reads
as a fact about the hex rather than as a price pulled out of the piece's worth — which is the trap
`models/identify.lua`'s fee block spends forty lines refusing. A blueprint may declare `fee`; the default
is `Curse.LIFT_COST` (120g).

The fee is deliberately **not much money**. The money is not the interesting half of the room: two trips
without your best weapon is the cost that gets weighed, and the fee is the button for a player who has
already decided they would rather not weigh it.

## Where curses come from

| vector | how | lifetime |
|---|---|---|
| **a find you paid to read** | `Identify.sealed` rolls one at **seal** time; it comes out when the Touchstone names the piece | until the Cathedral lifts it |
| **a trap** | `data/traps/hex_stone.lua`, through `ctx.curse(victim, id)` | until the Cathedral lifts it |
| **a cast** | `fx.curse(target, id)` → `Combat.curseItem` | on the party, until the rite; on a **foe**, the fight |
| **born hexed** | `curse = "<id>"` on an item **blueprint** | the piece was made that way |

`fx.curse` is the same verb with two lifetimes, and the asymmetry is the point rather than an oversight:
an enemy is rebuilt from its blueprint every fight, so a hex the party lays lasts exactly this battle,
while a hex laid *on* the party rides the item out of the rift. That is what makes a hexing **enemy**
frightening and a hexing **ability** merely good.

`Combat.curseItem` picks **at random** among the pieces that can carry one, where `Combat.steal` picks the
best. A theft is aimed — the point of stealing is what you get — and a curse is not. Random also makes it
read as a thing that *happened to* the victim, which is what a curse is.

### What can carry one

`Curse.canAfflict` is the gate every vector goes through:

- weapons, armour, utilities and abilities — the four types that sit in a grid cell for a campaign
- **not consumables**: a stack merges by id, so three draughts are one row and a hex on "the stack" is a
  hex on a thing that is not an object. Same argument `models/identify.lua` makes for leaving them out of
  the seal
- **not `noSteal`**: a beast's fangs are a body part, and there is no Cathedral visit that helps a wolf
- **not an unread husk**: the player would be told about a hex on an item whose name is still secret —
  though a hex may travel *inside* a seal, which is a different thing
- **not something already hexed**: one per piece, always

A body with nothing cursable shrugs a hex off entirely, and that is the counterplay rather than a failure
mode — it is legible from across the board once a player can tell a soldier from a beast.

### A find may be hexed

An unread piece has always been a bet whose worst outcome was a bad roll — a poor return on a bill, never
a bad thing to own. A hex is the other tail, and the room needed one: the interesting question at an
identification desk is not *how good*, it is *what did I just take into my house*.

`Identify.CURSE_BASE` 5%, climbing `CURSE_PER_LEVEL` 1.2 points per floorLevel to a `CURSE_MAX` of 20% —
roughly two hexed finds in a complete descent, weighted toward the bottom where the gear is worth keeping
and the deep curses live. The unit is **floorLevel** (1–15), not the floor number; getting that wrong is
the mistake `Identify.fee` records having made once already.

It is never a trap, because the Cathedral is free.

## The ladder

`depth` is the shallowest floorLevel a hex may be **rolled** at (a blueprint that declares none is
available from the first floor). Named curses — a cast, a boss's rule, a blueprint's own — ignore it.

| curse | depth | binds | what it does |
|---|---|---|---|
| The Clinging Hand | 1 | yes | binds, and nothing else |
| Dead Weight | 1 | yes | -1 movement |
| **Cold Iron** | 1 | no | the piece can never be **upgraded at the Forge** |
| The Witness | 2 | no | -3 luck, -2 skill |
| **The Shortened Arm** | 3 | yes | every reach one tile shorter (`abilityRange = -1`) |
| The Hungry Edge | 4 | yes | the bearer opens every fight bleeding |
| **The Crowding** | 4 | no | blows land 4 softer with an enemy in arm's reach |
| Thin Blood | 5 | yes | -2 defense, physical blows land 3 harder |
| **The Dulling** | 6 | no | every blow lands a quarter softer (`damageMultiplier = 0.75`) |
| The Long Hour | 7 | yes | every turn acted on costs 35% more of the clock |
| **The Tether** | 7 | yes | a quarter of every wound splashes to the nearest ally |
| **The Tithe-Taker** | 8 | yes | every action costs 3 more mana **and** 3 more stamina |
| The Blood Price | 9 | yes | every mana cost is paid in health |
| **The Open Door** | 9 | no | the bearer opens every fight Vulnerable: Dark |
| **The Long Memory** | 10 | yes | every debuff lands for the rest of the fight (`statusesPersist`) |
| The Shut Hand | 11 | yes | nothing recovers between fights |
| **The Hollow** | 12 | yes | the health pool is half the size (`halveMaxHealth = 2`) |
| The Anchor | 13 | yes | the bearer cannot move at all |
| **The Spreading** | 14 | yes | after each fight it may creep into a neighbouring cell |

Nineteen, across depths 1-14, and **six do not bind** - which is deliberate. Eight of the first nine
bound, and at that ratio the bind stops meaning anything; a loose hex on a piece worth carrying is a
question the player answers in the Armory instead of at a counter.

Three of the ten added on 2026-09-20 do a job beyond their numbers:

- **Cold Iron** never touches a fight. Its whole cost is the bench (`Forge.hexRefusal`, with its own
  `cursed` reason so the row greys with a word that points at the right building) - which makes it the
  hex that teaches the *room* where The Clinging Hand teaches the *bind*.
- **The Tether** is the only one about **position**. A body under it fights at arm's length from its own
  line, which cuts against every adjacency the game is built on.
- **The Spreading** is the only one with a **clock**. Left alone it eats a loadout a cell at a time, so
  "one more floor or go home" becomes a question about the Cathedral rather than about health bars.

Three of those are doing a specific job beyond their numbers:

- **The Clinging Hand** is the teacher. No stat penalty at all: the whole cost is that one of nine grid
  cells belongs to it now, and the size of that cost is set by *what got nailed*. A player meets it early,
  reads the tooltip, walks into the Cathedral, and learns what a rite is without having been hurt.
- **The Witness** is the one that does not bind, and the set needs exactly one. It can simply be taken
  off and shelved — and finding that out is what teaches that the bind on the others is the actual curse.
  It can also be **sold**, since `Vendor.sellValue` only refuses what is bound, and re-bought clean. That
  is deliberately left open: the counter's spread (half price out, full price back) is dearer than the
  100g lifting, so laundering a hex is a worse deal than paying for the rite, and closing the door would
  take away the one counterplay this curse is built around.
- **The Blood Price** might be a *gift*, and is left as one. On a mage it is a serious wound; on a knight
  who casts nothing it does nothing; on a big body with a small pool it is an upgrade. A curse whose value
  depends on who carries it could be answered by moving it — except that it binds.

## The Shaman

The discipline's premise widened on 2026-09-20 and nothing was unwound. It read *"spirit totems — summon
elemental spirits bound to hazards"*; it reads **binding** now — a spirit put into a thing and made to
stay there.

The old word was the wrong half of its own mechanic. "Summon" describes Call Spirit and nothing else on
the shelf: Bind Spirit's trick is that the squall belongs to the spirit rather than to the ground, the
Ancestor Mask binds an element to what you called, Ghost-Wind binds a spirit to the weather it walks
through. The verb those share is binding, and the summoning was only ever the first thing bound into.

Which is why the hexes belong here rather than on a discipline of their own: **a curse is a spirit bound
into somebody's gear.** Same verb, same craft, same counterplay — bindings come undone, by a spirit's
throat or by a priest's rite — pointed at an object instead of at a patch of ground. A separate Hexer
would have been a second set of names for one idea, which is the trade `docs/class-fold.md` refuses.

It also separates the Shaman from the **Totemist** (hunter × priest), which the old word did not: a
Totemist plants stakes that project fields, and a Shaman under "spirit totems" was a stake that walked.

The first curse stock, all `class = "shaman"`:

| item | what it does |
|---|---|
| `ability_lay_the_hex` | curses a piece of a foe's kit **and** deals dark damage — the bolt is the floor for a target with no kit |
| `ability_sink_the_anchor` | names The Anchor: that body cannot move. A hard lock, priced as one, and it needs something to sink into |
| `weapon_hexbrand` | a staff (so Wait → Focus); every blow hexes a piece of what it strikes, until that grid runs out |
| `utility_hexbinders_cord` | **born bound** — good numbers, and the cell belongs to it until somebody pays the rite |

## Three verbs: who may touch a binding

A curse has three answers and each belongs to somebody. **The split is load-bearing** - it keeps the
Cathedral a fixture of the loop instead of a chore - and `tests/curse_shelf_spec.lua` asserts it over the
whole shelf by reading the blueprints, rather than leaving it written down here and hoping.

| | verb | what it may do |
|---|---|---|
| **the Shaman** | *manipulate* | count them, move them, spread them, wake them, lend them. **Never ends one.** |
| **the Exorcist** | *end & prevent* | the two rites, and the ward |
| **the Cathedral** | *always open* | free-and-slow for every company, priest or not |

The one crack is deliberate: **Let It Walk** spends a hex to summon a spirit, and if that spirit is
killed the binding died with it. The Shaman still never lifts anything - they make it killable and
somebody else swings.

### The Shaman's shelf: counting and moving

A hex is a **resource** to this shelf, which is what turns paying for one into a decision. The count is
read through `ab.counter` with `counterGates = false` - the pair `weapon_last_word` already wears to grow
with every fallen ally - so the number on the grid badge, the number in the tooltip and the number the
effect multiplies by are one call and cannot drift.

| item | reads | what it does |
|---|---|---|
| The Reckoning | count | a staff; +25% damage per hex, with a deliberately poor floor |
| The Gathered Weight | count | +2 attack and +2 magic damage per hex (`Trait.liveBonus`, recomputed per read) |
| Speak for Them | count | Silences adjacent enemies one turn **per hex** - the count buying duration |
| The Common Burden | company | +1/+1 armour to the whole line per hex **anyone** carries |
| Rouse the Binding | **depth** | wakes the worst hex to strike; +15% a point of depth |
| Rebind | - | moves the deepest hex to an adjacent ally: a turn, a position, an adjacency |
| Let It Spread | - | passive; after each fight a hex may creep one cell |
| Let It Walk | - | spends a hex to summon a spirit, returned at the bell unless it died |

**What keeps the counting safe is that it reads one grid.** The body cashing four hexes in is the body
that cannot move, recovers nothing and has half a pool - the scaling is always paid for in the place it
is spent, and nine cells cap it.

`Rouse the Binding` is the only thing in the game that reads a curse's **depth** rather than the count,
which makes carrying one dreadful binding a different build from carrying four mild ones - and makes The
Anchor, the cruellest hex in the rift, somebody's best caster.

### The Exorcist's shelf: ending and preventing

"Lifting is a high-level priest thing" needed no new machinery. An ability is priced, a priced item is
shelf-gated on `unlockLevel`, and `Quest.shelfRung(player, "cathedral")` already reads **the roster's
best priest class level**. A company that never played the priest never sees these and pays the room.

| item | gate | what it does |
|---|---|---|
| The Lesser Rite | exorcist, rung 7 | lifts one hex from an ally; in a fight the binding **bursts** for holy damage |
| The Greater Rite | exorcist, rung 8 | channelled: lifts **every** hex in the company, and the burst grows with how many came off |
| Consecration | priest, found | nothing can lay a curse on that body's kit (`curseWard`) |

Both rites **burn as they lift**, which is what makes them abilities rather than housekeeping - and it
puts the Exorcist in the same argument as the Shaman's counting gear from the opposite side: one shelf
pays you to carry curses, the other pays you to carry them and then spend them all at once.

**Consecration is prevention**, which is neither other verb, and it costs a grid cell rather than a turn
or a fee - so it competes with the counting charms for the same nine slots. Ward the body or feed it.
The satchel is never warded: a hexed find read at the Touchstone is still a gamble for everybody.

## Casting outside a fight

The Lesser Rite exposed a gap. `Player.partyRestoratives` admits **consumables only**, on purpose
(*"a spell isn't spent by drinking"*), so there was no path in the game for a cast outside a battle -
which blocked out-of-combat healing too.

An ability now declares `outOfCombat = true` and is gathered by `Player.partyAbilities` into the same
overworld Use panel, beside the draughts, sharing one cursor. `kind` tells the two apart: a **drink**
spends a stack and is gone, a **cast** spends a pool that partly refills between fights.

A road cast runs a second, smaller effect - **`roadEffect(ctx)`**, with a four-verb context
(`heal`, `restore`, `liftCurse`, `say`). That is deliberate rather than lazy: an ability's `effect` is
written against Combat's forty-verb `fx` table, all of it about a board that does not exist out here, and
faking one would mean forty stubs that silently do nothing - the worst failure shape this codebase has.
So the road version says out loud what it is: The Lesser Rite lifts and bursts in a fight, and on a road
it lifts.

**It costs exactly what it costs in a fight** (authored decision, 2026-09-20 - no surcharge). The brake
is that mana is itself a carried resource: healing with it now is not having it for the next fight, and
`Player.camp` only hands part of it back. That is the one number here that a session of real descents
could argue with.

## Adding a curse

1. Write `data/curses/curse_<name>.lua`. Declare `name`, `description`, a `depth`, an effect (any of the
   item fields above, or `binds`), and a `fee` if the default is wrong for it.
2. That is all. The registry picks it up, the fold applies it, the tooltip prints it, the Cathedral lifts
   it, the save persists it, and `Curse.roll` may deal it at its depth.

`tests/curse_spec.lua` holds every blueprint to the schema — a name, a sentence, a real effect, a rule
name the engine actually reads, a depth and a non-zero fee.
