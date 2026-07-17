# Adding content

All game content is data-driven: drop a Lua file into the matching `data/` folder and
`models/registry.lua` picks it up by filename (no registration). Blueprints are read-only —
models copy them into runtime state.

Adding a **weapon** has its own contract — each weapon belongs to a family (axes cleave, daggers
bleed) and inherits its mechanics. See [weapons.md](weapons.md).

Adding **any item** has one too, because every item must answer which shelf it goes on: each class
owns a vocabulary, and an item's `class` should be the shelf whose vocabulary it speaks. See
[classes.md](classes.md).

## The progression loop

Seven class vendors (`data/vendors/`) each own a hub building, a shelf of items, and a line of
quests. The loop: **pick a quest by its sponsor → complete it → earn gold, prestige, and
reputation with that sponsor → spend it on the stock that reputation unlocked.**

An item's `class` (`fighter`, `priest`, `hunter`, `knight`, `mage`, `rogue`, `alchemist`) decides
*where you buy* it, never *who may equip it* — anyone can carry anything, which is what lets a
player build a bespoke class by mixing shelves (a ninja is mage gear on a rogue).

Each vendor also names a deadly `sin`, and its quest line ends facing that sin's general. Seven
generals dead opens the Gate Below. Read [story.md](story.md) before adding a quest to the end of a
vendor's line, or a boss of any kind.

Health and mana carry across the battles **within** a quest, so a run is a war of attrition.
Returning to the hub calls `Player.restore`, which refills the whole roster — attrition lasts a
quest, not a campaign. That is why `models/save.lua` stores no current resource values.

## Character growth

Characters have no individual XP. Every roster member's **level tracks the player's global
prestige** (`Player.syncLevels`, run on each prestige gain and on load), so swapping party members
carries no grind penalty. What makes two same-level characters differ is *how you played them*:
each character tallies which class's items it casts (`Combat.useItem` → `Character.recordUse`), and
on every level-up it gains the stats of its **most-used class** (`models/growth.lua`). A knight you
keep casting Fireball with grows into a battlemage.

- **Growth tables** live in `data/growth/<class>.lua` — one flat table of per-level stat gains per
  `Item.CLASSES` entry (`health`/`mana`/`stamina` gains raise the pool's `max`). Gains are
  deterministic (no RNG) and `movement` is deliberately never grown.
- A character blueprint may set an innate **`class`** (`data/characters/character_knight.lua` → `"knight"`),
  used as the growth class before it has cast anything and as the tie-break; a class-less blueprint
  falls back to `Growth.NEUTRAL_CLASS`.
- Growth is baked onto `char.stats` and the running total kept in `char.growth`; the save stores
  `level`/`classUse`/`growth` and re-bakes on load (`Save.VERSION` 3). The post-quest **Company
  Advancement** overlay (`ui/panels/advancement.lua`) shows each member's level-up.

## Add a quest

Create `data/quests/<id>.lua`:

```lua
return {
    name = "Bandit Ambush",
    description = "Raiders have blocked the north road.",
    difficulty = "Easy",
    sponsor = "bastion",   -- a data/vendors/<id>.lua; reputation is earned with them
    rewardGold = 50,
    rewardRep = 20,        -- reputation with the sponsor
    rewardPrestige = 1,
    requiredPrestige = 1,  -- appears once the player's prestige reaches this
    -- optional gates:
    requiredRep = { vendor = "cathedral", rank = 2 }, -- hidden until you have their trust
    requiredQuests = { "general_wrath", ... },        -- ALL must be done; see below
    repeatable = true,     -- stays on the board after completion (grind quests)
    -- optional rewards:
    rewardItems = { "mail_of_the_unappeased" },  -- granted into the stash on completion
    gateHint = "beneath the sand",               -- a fragment shown on a quest that requires this one
}
```

It shows up automatically on the Quest Board once the player meets every gate and has not
already finished it (`Quest.available` in `models/quest.lua`). `Quest.complete` pays it out from
the objective-win branch in `states/game.lua` and saves.

Prestige and reputation are **hard** gates — fail one and the quest is not on the board at all.
`requiredQuests` is a **soft** lock: hold at least one prerequisite and the quest appears `locked`,
showing "3 of 7 keys" and the `gateHint` of every prerequisite already finished. The board must refuse
to start a locked quest (`ui/panels/quest_board.lua`). Seeing what you have not yet earned is the point
of a ladder — the same reason `Vendor.stock` flags rank-locked items rather than hiding them.

## Add a conversation

Story scenes are visual-novel overlays (large portraits + a bottom text box) that can play over any
screen — the hub, the overworld, or **a battle mid-turn** — freezing it until they end. Create
`data/conversations/<id>.lua`:

```lua
return {
  title = "Debut on the Sand",                 -- optional; shown top-left
  cast  = { "character_knight", "character_priest", "colosseum" }, -- speaker ids, drawn left->right; non-speakers grey out
  script = {
    { "colosseum", "You want blood on the sand? Prove it." },  -- a node is { speaker, line }
    { "character_knight",    "We only want the quest." },
    { "colosseum", "Everything has a price. Which is it?",
      choices = {
        { "\"Coin.\"",  goto = "coin"  },       -- a choice jumps to a node's `id`
        { "\"Honor.\"", goto = "honor" },
      } },
    { "colosseum", "Honest.",   id = "coin",  goto = "end" },  -- `goto = "end"` finishes early
    { "colosseum", "Reckless.", id = "honor" },                -- the last line finishes too
  },
}
```

- A node is `{ "<speaker id>", "<text>" }`, played top-to-bottom. `goto` jumps to the node with that
  `id`; `goto = "end"` (or falling off the end) finishes; a node with neither just advances.
- `cast` is who stands on screen for the whole scene; each line's speaker becomes active (full colour
  + a name plate), the rest grey out. A speaker id must be a `data/characters` or `data/vendors` id —
  that is where the name and large `portrait` come from (a missing portrait falls back to a lettered
  box). For an off-roster voice, override inline: `{ "narrator", "...", name = "???" }`.
- Player controls are automatic across mouse + keyboard + gamepad (advance: Enter / Space / click;
  choose: up/down; skip: Esc / B).

### Gating a scene on progress

Write the scene for the whole story, then let it pare itself down to fit the save it plays in. A cast
entry may carry a `when` condition, and a **block** of the script may too — `Conversation.resolve`
drops what does not apply before the widget ever sees it, so a priest who has not been recruited is
neither on stage nor in the script:

```lua
cast = { "character_knight", "character_mage", { id = "character_priest", when = { has = "character_priest" } }, "colosseum" },
script = {
  { "colosseum", "Fresh blood for the sand." },
  -- One block, one condition: these lines stand or fall together.
  { when = { has = "character_priest" }, script = {
    { "character_priest", "The Light is watching, even here.", id = "ready" },
    { "character_mage",   "Watching, and unimpressed. Open the gate." },
  } },
}
```

**Gate the exchange, not the line.** The mage above is *answering* the priest, so gating only the
priest's line would leave the mage retorting to a remark nobody made. That is what blocks are for —
they group the lines that only make sense together. `tests/conversation_spec.lua` enforces the half of
this it can prove: a conditional cast member may only speak inside a block that requires them.

Conditions are **data, not functions** (unlike an encounter's `condition(ctx)`) for two reasons: the
extractor rewrites these files and would erase a closure, and data can be inspected — which is how the
spec proves the rule above. The grammar:

| `when`                            | holds when                                    |
| --------------------------------- | --------------------------------------------- |
| `{ has = "character_priest" }`              | the character is on the roster (recruited)     |
| `{ notHas = "character_priest" }`           | …and its negation                              |
| `{ done = "vault_heist" }`        | the quest is completed                         |
| `{ notDone = "vault_heist" }`     | …and its negation                              |
| `{ prestige = 3 }`                | player prestige is **at least** 3              |
| `{ all = { c1, c2 } }`            | every sub-condition holds                      |
| `{ any = { c1, c2 } }`            | at least one holds                             |

Several keys in one table AND together (`{ has = "character_priest", prestige = 2 }`). Blocks nest, and an inner
condition can only narrow its parent, never escape it. An unknown key raises rather than quietly
passing, so a typo'd `{ hass = ... }` fails loudly instead of reading as "always show".

A `goto` aimed at a line that got dropped is **re-pointed to the next surviving line** (or `"end"` if
there is none), so gating a block can never strand a branch — jumping into the priest block above
simply rejoins the scene where it would have anyway.

Two rules the spec holds you to: every authored line must be reachable in a fully-unlocked save (a
condition nothing can satisfy is dead content — usually a typo'd id), and gated speakers must be
guarded as described above.

**Play it** from anywhere with `require("models.conversation").play("<id>", onDone)` (the current
screen freezes and resumes in place when it ends), or hang it off a quest by adding `intro = "<id>"`
(plays over the hub before the quest starts) or `outro = "<id>"` (plays on victory) to the quest
blueprint — both are threaded through `Quest.available` for you.

**Then run the extractor** — required before committing:

```powershell
& "E:\LOVE\lovec.exe" . extract-strings
```

It stamps a stable localization id (`tag`) into every line and syncs the string grid
`data/lang/strings.lua` (new lines get an `en` cell; translation columns start blank). Do **not**
hand-edit the `tag`s or the `en` column. Note that stamping **rewrites the conversation file from the
data**, so a comment written inside one does not survive the next extraction — put the explanation in
a commit message or here instead. `tests/conversation_spec.lua` fails if a line has no tag or
the `en` cell is stale, so it doubles as the "did you forget to extract" guard. See
[localization.md](localization.md) for the translation model. (During development, the main menu has a
debug **Extract Strings** button that runs the same step.)

## Add a vendor

Create `data/vendors/<id>.lua`:

```lua
return {
    name = "The Colosseum",
    class = "fighter",     -- must be a key of Item.CLASSES
    description = "...",
    ranks     = { 0, 40, 100, 200 },  -- ascending reputation thresholds; ranks[1] must be 0
    rankNames = { "Recruit", "Contender", "Champion", "Legend" },
}
```

Then point a building at it with `panel = "party", vendor = "<id>"` (the Party screen opens in store
mode when a `vendor` is named).

**Stock is derived, not authored.** A vendor sells every item whose `class` matches its own and
which has a `price`. To put an item on a shelf, give it both:

```lua
tags  = { "sword", "slash", "physical" },  -- combat: damage scaling + armor mitigation
class = "fighter",                         -- shop: which vendor stocks it
price = 60,
repRank = 1,  -- reputation rank needed to buy it (default 1); higher ranks show as locked
```

`class` is deliberately its own field rather than an entry in `tags`: `tags` drives combat
scaling and `resist` lookups, so a shop taxonomy living there would be one typo away from armor
mitigating "rogue" damage. An item with no `class` is universal and no vendor stocks it; an item
with a `price` but no `class` is unbuyable dead data, and `tests/progression_spec.lua` fails it.

## Add a building to the hub city

Create `data/buildings/<id>.lua`:

```lua
return {
    name = "Guild Hall",
    order = 5,             -- sort + keyboard/gamepad nav order
    x = 980, y = 340, w = 270, h = 140,  -- clickable hotspot in the 1280x720 logical space
    panel = nil,           -- module name under ui/panels/, or nil for the placeholder
    vendor = nil,          -- vendor id, for shop buildings (panel = "party", store mode)
    unlockPrestige = 3,    -- locked (dimmed, non-clickable) until prestige >= 3
}
```

This is how **the city grows over time**: give new buildings a higher `unlockPrestige` and they
appear locked, then unlock as the player earns prestige. Positions are in the 1280×720 logical
coordinate space (see `scale.lua`), which is letterbox-scaled to the real window; place them
over the corresponding spot on `assets/hub/city.png`. The city is laid out on a **4/4/3 grid of
270×140 cards with 40px gutters** — columns at `x = 40, 350, 660, 970`, rows at `y = 150, 340,
530` (the last row centered at `x = 195, 505, 815`). Stay on that grid so hotspots never overlap.

> `Building.list`, `Quest.available`, `Item.instantiate` and `Character.instantiate` copy blueprint
> fields **one at a time**. A new field must be added to that copy or it silently reads as `nil` at
> runtime — and silently is the word: nothing errors, the feature just never happens.

## Add a pop-up panel for a building

1. Create `ui/panels/<name>.lua` exposing the panel interface:

   ```lua
   local Panel = {}
   Panel.__index = Panel

   function Panel.new(opts)          -- opts: { title, prestige, onClose }
       local self = setmetatable({}, Panel)
       self.onClose = opts.onClose
       -- build widgets here (fonts/graphics are safe: panels load only when opened)
       return self
   end

   function Panel:update(dt) end
   function Panel:draw() end          -- draw a dimmed overlay + your framed box
   function Panel:mousemoved(x, y) end
   function Panel:mousepressed(x, y, button) end
   function Panel:keypressed(key) if key == "escape" then self.onClose() end end
   function Panel:gamepadpressed(joystick, button) if button == "b" then self.onClose() end end

   return Panel
   ```

   Reuse `ui/menu.lua` for any list of choices (pass `opts.centerX` to seat it in a column) —
   it gives you mouse + keyboard + gamepad for free. `ui/panels/quest_board.lua` is a full
   example; `ui/panels/placeholder.lua` is a minimal one.

2. Point the building's `panel` field at the module name (the filename without `.lua`):

   ```lua
   panel = "guild_hall",
   ```

`states/hub.lua` requires `ui/panels/<panel>` when the building is clicked, constructs it with
`{ title, prestige, onClose }`, and manages it as the modal `activePanel`.

## Add an enemy

Enemies reuse the party-character schema, so drop a stat block into `data/characters/<id>.lua`
(a `startingItems` grid is optional for foes):

```lua
return {
    name = "Bandit",
    sprite = "assets/chars/bandit.png",
    stats = {
        health = 60, mana = 0, stamina = 50, -- resource stats (become {max,current})
        damage = 12, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 3, -- spaces per turn on the battle grid
    },
    -- Innate reaction: place a bound signature relic in the loadout (see below).
    startingItems = {
        false, false,                  false,
        false, "sig_unappeased_heart", "crimson_greataxe",
        false, false,                  false,
    },
}
```

**Traits** are how a character (a boss especially) gets an identity rather than just bigger numbers.
A trait is a `data/traits/<id>.lua` file exposing any of `onCombatStart`, `onDamaged` (fires after
mitigation, and only if the unit survived), `onCast`, `onDeath`. A trait reaches a unit through an
**item**: any item that declares `traits = { "<id>" }` grants them to whoever carries it in their 3×3
grid. A character's *innate* reaction is delivered by a **bound signature relic** — an item with
`bound = true` (never moved, stowed, sold, or stolen, only forged; see `models/item.lua` `Item.isBound`)
placed in the loadout grid, conventionally the center cell. That same mechanism is how a slain
general's relic hands its rule to the player. A signature relic carries a real item `type`
(armor/utility/...) and lives in that type's folder; `bound`, not the type, is what locks it. See
[story.md](story.md) and the `sig_*` relics under `data/items/armor/` and `data/items/utility/`.

> The runtime `char.traits` list still exists as a low-level hook (tests and summon-copies use it),
> but character *blueprints* no longer carry a `traits` field — author the innate as a bound signature
> item instead.

A trait that **retaliates** — answers a blow with one of its own — declares what provokes it as data
rather than re-checking the same five conditions in its hook:

```lua
counter = { reach = "melee" },   -- see Trait.mayCounter in models/trait.lua for every field
onDamaged = function(ctx)
    if not ctx.mayCounter() then return end   -- the gates: reach, side, cooldown, suppression, ...
    if not ctx.pay() then return end          -- last, so a reflex that declines is never billed
    ctx.basicAttack(ctx.attacker)
    ctx.setCooldown("<id>", ctx.def.magnitude)
end,
```

Declaring it is what puts the reflex on the player's **hover preview**: `Trait.counterPreview` reads
the same rule to warn them, before they commit the turn, that this swing will be answered and by what
(`ui/action_preview.lua`). A retaliation that hand-rolls its gates instead still fires — it just fires
as a surprise, which is a bug in a tactics game.

## Scale a combat encounter's roster

A `combat` / `elite` encounter fields its enemies in the battle arena via `composition`, a
`function(ctx)` that returns a list of `data/characters` ids and **scales with player prestige**
(`ctx = { prestige, biome, quest }`), mirroring the dynamic `weight`:

```lua
composition = function(ctx)
    local p = ctx.prestige or 1
    local list = {}
    for i = 1, 2 + math.floor(p / 2) do list[i] = "character_wolf_grunt" end
    if p >= 3 then list[#list + 1] = "character_wolf_alpha" end -- an alpha joins at higher renown
    return list
end,
```

A quest's **objective** battle is authored on `map.objective` — its own `composition` plus a win
condition `win = { type = "killAll" | "survive" | "assassinate", turns = N, target = "<id>" }`
(`win` omitted ⇒ `killAll`):

```lua
objective = {
    name = "The Warlord",
    composition = function(ctx) return { "character_warlord", "character_champion", "character_champion" } end,
    win = { type = "assassinate", target = "character_warlord" },
},
```

Encounters without a `composition` fall back to a single generic foe.

## Escort missions: allies and `protect`

`win.protect = "<character id>"` is a **composable loss condition, not a win type**: whatever the
win type is, the battle is lost the instant that character dies. Pair it with `allies`, a list of
non-party characters who spawn on the party's side under AI control and fight for themselves:

```lua
objective = {
    name = "Ambush at the Pass",
    composition = function(ctx) return { "character_bandit_chief", "character_bandit", "character_bandit" } end,
    allies = { "character_caravan_master" },                        -- AI-run, on the party's side
    win = { type = "killAll", protect = "character_caravan_master" }, -- ...and he must live
},
```

That expresses "clear the ambush, and the caravan must survive" — or, with `survive`, "hold eight
turns and keep the charge alive" — with no exit-tile or pathing machinery. `Combat.planEnemyAction`
targets by `unit.side`, so an ally never turns on the party. `Arena.build` seats allies on party
spawn points *after* the party, falling back to a procedural layout if a curated arena hasn't
authored enough of them.

True "escort to an exit tile" is not implemented; it would need exit tiles in `models/arena.lua`.

## Add a curated battle arena

Battle arenas are procedurally generated, and any **curated** layouts you add join the same
random pool: each battle `models/arena.lua` picks uniformly between a fresh procedural map and
the curated arenas tagged for the quest's biome. Drop one into `data/arenas/<id>.lua` — tile
*types* plus spawn positions (no bound units; the encounter's scaled roster fills the enemy
spawns):

```lua
return {
    biome = "forest",              -- used to match this arena to a quest's biome
    tiles = {                      -- 8 rows x 8 cols of Arena.TILE_PROPS types
        { "ground", "ground", "ground", "ground", "ground", "ground", "ground", "ground" },
        -- "forest"/"rough"/"water" = move penalty, "obstacle" = blocked. Terrain also shapes LINE
        -- OF SIGHT (each type carries a `sightCost`): "obstacle"/"mountain" block a ranged shot,
        -- "forest" is soft cover that only lowers it (two stacked tiles block). See below.
        -- Terrain also carries TILE TAGS: "water" conducts lightning, "forest" catches fire.
    },
    partySpawns = { { x = 2, y = 8 }, { x = 4, y = 8 }, { x = 6, y = 8 } },
    enemySpawns = { { x = 2, y = 1 }, { x = 4, y = 1 }, { x = 6, y = 1 } },
    traps = {                      -- optional authored traps (hidden from the player until detected)
        { id = "spike_trap", x = 3, y = 4, side = "enemy" },
    },
}
```

The fastest way to author one: in a battle press **F5** (dev-only debug save) to serialize the
current arena to `data/arenas/<biome>_<timestamp>.lua`, then rename and hand-edit it (F5 also
writes back any authored `traps`). See `data/arenas/forest_01.lua`.

### Line of sight & terrain cover

Every arena tile carries a `sightCost` (set per type in `Arena.TILE_PROPS`, alongside `moveCost`
and `walkable`). When a **sight-requiring** ability fires, `models/combat.lua` sums the `sightCost`
of the tiles the straight line crosses (endpoints excluded); the line is blocked once the sum
reaches `Combat.SIGHT_BLOCK` (2). So `obstacle`/`mountain` block a shot on their own, while
`forest` (1) is **soft cover** that only lowers the line — a lone copse is see-through, but two
stacked tiles screen the lane. Cover shapes both the board and how the enemy AI positions.

Make an ability respect cover by adding `requiresSight = true` to its `activeAbility` — do this for
ranged attacks (see `data/items/weapon/bow.lua`, `data/items/ability/ability_fireball.lua`,
`ability_jolt.lua`). It gates targeting (`Combat.useItem` / `abilityTargets`), the red threat
highlight, and enemy planning; the armed-range overlay then stops at cover so the player sees the
clear line. Adjacent (range-1) melee has no tile between attacker and target, so it never needs it.

### Positional buffs (high ground & field objects)

A tile can also grant a **positional bonus** to whatever unit stands on it, via an optional `bonus`
bag in its `Arena.TILE_PROPS` entry — `mountain` uses `bonus = { range = 1 }` so high ground
extends a unit's reach by a tile. `Combat.fieldBonus(combat, x, y)` aggregates these, and
`Combat.abilityRange` folds the `range` bonus into every reach measurement (targeting, the threat/
range highlights, enemy planning), so a unit atop high ground both threatens and can strike one
tile farther, and the overlay shows it.

The mechanism is deliberately generic so **placed objects** (a future vantage totem, a shrine) can
grant the same buffs: `fieldBonus` also folds in `combat.fieldObjects`, a list of
`{ x, y, bonus = { range = 1 } }`. Drop objects into that list and any `bonus` key they carry
stacks with the terrain — no other wiring needed. See `tests/field_bonus_spec.lua`.

### Tile tags (what the ground is made of)

Terrain type answers *where* a unit can walk; **tile tags** answer *what the ground is*, for effects
that ask a question rather than name a type. A tile carries the union of three sources, and
`Combat.tileHasTag(combat, x, y, tag)` asks all three at once:

| Source | Declared as | Example |
| --- | --- | --- |
| Terrain | `tags` in its `Arena.TILE_PROPS` entry | `water` is `{ "conductable" }`, `forest` is `{ "burnable" }` |
| A hazard on the tile | `tags` in `data/hazards/<id>.lua` | a Rain cloud is `{ "water", "conductable" }` |
| Whoever stands there | `tileTags` in `data/status/<id>.lua` | `wet` is `{ "conductable" }` |

So a soaked knight, a rain cloud and a river are **the same thing** to a lightning bolt — no branch
anywhere has to know which one answered. Two mechanics ride on this today, and they are the same
mechanism pointed at different tags:

- **`burnable`** — fire creeps into it. A hazard declaring `spread = { intoTag = "burnable" }` seeds
  a copy of itself on adjacent tagged tiles each tick (`Hazard.spread`).
- **`conductable`** — lightning arcs into it. A cast tagged `lightning` strikes every adjacent
  conductable tile after its effect resolves, for `Combat.CONDUCT_FACTOR` (half) of its magnitude,
  carrying the cast's own tags — so Wet's `vulnerable = { lightning = N }` amplifies the arc exactly
  as it does the direct hit. Side-agnostic, like fire: soaking the ground beside your own line is a
  real risk. See `Combat.conductLightning` and `tests/conduction_spec.lua`.

**A new interaction is a new tag on the data, not a new branch in the model.** To make oil slicks
catch, tag the hazard `burnable`; to make a Frozen unit conduct, give the status
`tileTags = { "conductable" }`. Nothing in `models/` changes either time.

## Add a status effect

Status effects are timed effects on a combat unit, measured in **ticks** (the initiative
`models/combat.lua` subtracts each turn — the amount folded into `combat.clock`). Drop a
blueprint into `data/status/<id>.lua` with any of the hooks `models/status.lua` calls:

```lua
return {
    name = "Poison",
    abbr = "Ps",                   -- short badge label (2-3 chars; longer is squeezed to fit)
    color = { 0.5, 0.85, 0.4 },    -- badge tint (board + turn strip)
    duration = 6,                  -- ticks before it expires
    magnitude = 4,                 -- effect strength (meaning is up to the hooks). A recurring
                                   -- effect quotes it PER TURN; see onTick below.
    lingers = true,                -- keep it when leaving the zone that granted it: see "Auras" below
    -- Hooks receive ctx = { combat, unit, status, magnitude, moveBudget } + bound helpers
    -- (damage / applyStatus / unitsNear / accrue). Any subset is optional:
    onApply     = function(ctx) end,   -- when first applied / re-applied (stun bumps initiative)
    onExpire    = function(ctx) end,   -- at 0 remaining ticks
    onTick      = function(ctx)        -- the hook for a RECURRING effect (burn, poison, regen).
        local n = ctx.accrue(ctx.magnitude)  -- per-turn magnitude -> whole units for this tick
        if n > 0 then ctx.damage(ctx.unit, n, { "poison" }) end
    end,
    onTurnStart = function(ctx) end,   -- only for what is genuinely scoped to a TURN (Defending and
                                       -- Invisible self-expiring at their owner's next one)
    onTurnEnd   = function(ctx) end,
    onEnterTile = function(ctx) end,   -- the unit crossed onto a tile on foot (bleed)
    onDamaged   = function(ctx) end,   -- the bearer took a hit and lived (sleep breaks on it)
    -- blocksMove = true,               -- the unit cannot move this turn (root)
    -- turnEndMoveCost = function(ctx) return ctx.moveBudget end, -- pay full move cost anyway
    -- resistible = "magical",          -- opts into resistance: see below
    -- illusion = true,                 -- a lie about a body: Dispel Illusions tears it down
}
```

Apply one from an ability or trap effect via `fx.applyStatus(target, "status_poison", { duration = 8 })`
(re-applying refreshes the duration; one instance per id). See `data/status/status_stun.lua` and
`data/status/status_root.lua`.

**A recurring effect belongs on `onTick`, not `onTurnStart`.** Durations are measured in ticks, and a
single rebase routinely elapses more ticks than a short status has left — a turn costs about
`Status.TICKS_PER_TURN`, while Burn lasts 3 — so a turn-driven effect can expire before its bearer's
next turn ever arrives and never fire at all. It would also charge a slow unit no more than a fast one
for the same stretch of time. Quote `magnitude` per turn and hand it to `ctx.accrue`, which converts it
to this tick's share and banks the fraction until a whole point has built up.

`onEnterTile` fires only for movement **across the ground** — a walk, or being shoved / pulled /
trampled — never for a blink, a swap, or a summon's arrival (see `Combat.enterTile`'s `reason`). It
is what makes a *positional* effect possible: `data/status/status_bleed.lua` charges its magnitude per tile
crossed and nothing at all for standing still.

`ctx.damage(unit, amount, tags, opts)` passes `opts` straight to the damage core, so a tick can be
`{ raw = true }` (armor-piercing). Reach for it when the effect is not a blow being blocked: defense
stats run 6–10, so a mitigated tick floors at 1 and its magnitude stops meaning anything.

### Resistance (`resistible`)

A status that takes a unit out of the fight — Sleep, Polymorph — must be resistible, or it is simply
the best spell in the game. Declare `resistible = "magical"` (or `"physical"`) and `Status.apply`
scales the duration before the status ever lands:

```
R        = magicDefense (or defense) + statusResist        -- the target's ward
duration = duration * 12/(12 + R) * 0.5^(times applied this battle)
```

Below one tick it does not land at all (`Status.apply` returns nil and logs "shrugs off"). Nothing
here rolls — the same cast on the same target always buys the same ticks — which is deliberate: a
hard-control effect that lands "usually" is one whose counterplay is praying. Two consequences worth
knowing when you author one:

- **The ward curve is a softcap**, so magicDefense alone never reaches immunity and never stops being
  worth another point. Armor grants its ward as an ordinary flat `bonus = { statusResist = N }` (see
  `data/items/armor/armor_skeptics_harness.lua`) — no plumbing of its own.
- **Diminishing returns are what bound it.** Every repeat on the same victim is halved again, so a
  bounded number of casts reaches "does not land", by arithmetic rather than by an `immune` flag.
  Refusals count too, so an attacker cannot reset a target's immunity by casting into it.

`onApply` runs only *after* this gate, so a shrugged-off cast never fires it — which is what lets
`data/status/status_polymorph.lua` safely put its whole effect (wearing the shape) in `onApply`.

See `models/status.lua` for the full contract and `tests/resist_spec.lua` for the pinned numbers.

## Transform a unit into another character

`models/transform.lua` exchanges a unit's **body** (`unit.char`) for another character blueprint's,
keeping the same unit: same tile, same turn, same initiative slot, same health bar. It is not a summon
(which adds a second unit) — a pigged knight *is* the knight.

```lua
effect = function(fx)
    fx.transform(fx.target, "pig")   -- a self-cast also binds the ability's `reserve`
end
```

The rules that matter when authoring a shape:

- **Pools carry across; everything else comes from the shape.** Health/mana/stamina (and the
  reservations constraining them) travel from the original — so a transform changes what a unit can
  *do*, never how much killing it takes. A shape that brought its own health would make polymorph an
  execute. Put placeholders in the blueprint's resource stats; they are never read.
- **A self-transform reserves like a summon.** Declare `reserve = { stat = "mana", percent = ... }`
  and the shape holds it until it ends. Don't also charge a `cost` — a reservation is already both a
  price and a lock (compare `ability_summon_wolf.lua`, which charges none either).
- **A status owns the shape's timer**, and its `onExpire` calls `ctx.revert()`. Since `Status.remove`
  and `Status.cleanse` both fire `onExpire`, every ending (countdown, Cure, dispel) reverts — there is
  no path that strands a knight as a pig.
- **`unarmed = false`** on a character blueprint gives a body with no natural weapon at all: that,
  plus no `startingItems`, is what makes a pig actionless but still able to move.
- **Tag shape statuses `illusion = true`** so Dispel Illusions can tear them down.

See `data/characters/character_pig.lua`, `data/status/status_polymorph.lua`, and `tests/transform_spec.lua`.

## Add a trap

Traps are tile objects owned by a side, hidden from opponents until a unit carrying a
`"detect traps"`-tagged item is within its `detectRadius`. A unit that paths **over** an opposing
trap triggers it; a revealed trap can be attacked down. Drop a blueprint into
`data/traps/<id>.lua`:

```lua
return {
    name = "Spike Trap",
    sprite = "assets/traps/spike_trap.png",
    health = 6,                           -- HP a revealed trap soaks before breaking
    tags = { "trap", "pierce", "physical" },
    damage = 18,                          -- base; the placing ability scales it up via trap.amount
    -- ctx = { combat, trap, victim } + bound helpers (damage / applyStatus / unitsNear). Read
    -- `ctx.trap.amount` (the item-level-scaled magnitude) and fall back to the blueprint:
    onTrigger = function(ctx) ctx.damage(ctx.victim, ctx.trap.amount or ctx.trap.def.damage, ctx.trap.tags) end,
    -- onDestroy = function(ctx) end,     -- when damaged to 0 HP
    -- consumedOnTrigger = false,          -- default true: spent after one trigger; false = persistent
}
```

Get traps onto the field two ways: **authored** on an arena's `traps` list (above), or
**summoned** in-battle by an ability that targets a tile — give the ability `target = "tile"`
(any in-range cell) and call `fx.placeTrap(fx.tx, fx.ty, "spike_trap", { amount = 18 + fx.level })`
in its effect. Anything an item **summons or places** (a summon, trap, hazard, or wall) scales off
`fx.level`, the item's upgrade level (0-based): pass an `amount` (effect magnitude), `duration`
(lifespan), or `health` and the runtime object carries it — `Trap.preview` / `Hazard.preview` quote
the scaled numbers in the tooltip. A unit reveals enemy traps by carrying a detector item
(`tags = { "detect traps" }`, `detectRadius = 2`).
See `data/traps/spike_trap.lua`, `data/traps/snare_trap.lua`, `data/items/ability/ability_spike_trap.lua`, and
`data/items/utility/utility_trap_sense.lua`.

## Stackable consumables

Only **consumable** items stack: a bundle of the same consumable shares a single inventory slot
with a running `quantity` (its "limited number of uses"), while every other type stays
one-per-slot. Adding a duplicate consumable (`Character.addItem`) merges it into the existing
stack up to a per-slot cap — `Item.DEFAULT_MAX_STACK` (9), overridable per blueprint with a
`maxStack` field — and only the overflow claims a new slot. A consuming use
(`activeAbility.consumesItem`) decrements the stack, floored at 0. `startingItems` is a **positional
3×3 grid** (row-major; cell `i` holds entry `i`; `false`/`nil` is an empty cell), so a stack is
authored as a `{ id, count }` cell rather than by repeating the id (or built at runtime via
`Item.instantiate(id, quantity)`):

```lua
startingItems = {
    { "healing_potion", 3 }, false, false, -- a x3 potion stack in cell 1
    false,                   false, false,
    false,                   false, false,
}
```

A spent stack **keeps its (now empty) slot** rather than vanishing: `Combat.isDepleted(item)`
reports quantity 0 and gates activation (`Combat.useItem` refuses, the slot greys out with an
`x0` badge, and it can't be armed) until it's restocked — `Character.addItem` merges a fresh
stack back into the empty slot to re-enable it. The item grid draws an `xN` badge on a stack and
the hover tooltip shows its remaining `Quantity`. See `models/item.lua`
(`Item.isStackable` / `Item.maxStack`), `models/combat.lua` (`Combat.isDepleted`), and
`tests/stacking_spec.lua`.

## Add a summon ability

A summon ability puts any `data/characters/` blueprint on the field as a real unit: it joins the
turn order, obeys whoever called it, and carries its own items. Use `target = "tile"` (the clicked
cell arrives as `fx.tx` / `fx.ty`) and call `fx.summon` in the effect:

```lua
activeAbility = {
    name = "Summon Wolf",
    target = "tile", range = 1, speed = 6,
    reserve = { stat = "mana", percent = 0.25 }, -- see below
    effect = function(fx)
        fx.summon("wolf_grunt", fx.tx, fx.ty, {
            scaling = { health = 2, damage = 0.5 }, -- stat = base + amount * factor
            amount = 10 + fx.level,       -- scales off the item's upgrade level (base 10, +1 per level)
            -- duration = 24,              -- ticks before it fades; omit = stands until slain
            -- stats   = { health = 60 },  -- flat overrides of the blueprint's stats
            -- items   = { "fangs" },      -- replaces its startingItems entirely
            -- control = "none",           -- default: inherit the summoner's controller
            -- fragile = true,             -- any hit at all is lethal
        })
    end,
}
```

`fx.copy(x, y, opts)` summons a duplicate of the **caster** instead — its current stats, wounds and
all, plus a fresh copy of its grid. Mark an item `noCopy = true` to keep it out of the duplicate
(otherwise a doppelganger carries the doppelganger ability and summons itself). See
`data/items/ability/ability_summon_wolf.lua` and `ability_doppelganger.lua`.

**One summon per item.** Whatever `fx.summon` / `fx.copy` puts on the field is stamped onto the item
that called it (`Combat.activeSummon`), and the ability **cannot be cast again while that creature
lives** — it is grayed out with an "Active" badge, the tooltip names what's holding it, and the AI
won't pick it either. Nothing has to be declared for this; it applies to every summon ability. The
claim clears the moment the creature falls (or is dismissed with its summoner), and never carries
into the next battle. `Combat.itemBlockReason` returns `kind = "active"` while it stands.

**Duration** is optional. `duration = 24` gives the creature 24 *ticks* — the same currency a status
or a hazard is measured in, counted down by `Combat.rebase` — after which it fades on its own,
releasing its reservation and freeing the ability. Omit it and the summon is indefinite: it stands
until something kills it, or until its summoner falls. That is the whole difference between Summon
Wolf (a permanent body, limited only by the mana it locks away) and Summon Fire Elemental (a burst
of pressure on a timer). The card counts a timed summon down in its badge; the tooltip quotes
`Duration` as a number, or "Until slain" for an indefinite one.

Both endings run through `Combat.dismiss`, which takes a summon off the field *without* it having
died: it logs a fade rather than a defeat, dismisses anything that summon was itself sustaining, and
releases its reservations.

**Reservation.** `reserve = { stat, percent }` commits a share of the pool's *maximum* for as long
as the summoned creature lives. A reservation is both a price and a lock: the amount is **spent out
of `current` on the cast** — so the cast is refused unless the caster actually holds it — and the
pool's *ceiling* drops by the same amount, so what was spent cannot be regenerated back while the
creature stands. It never lowers `max`, so reserving life genuinely leaves you with less life to
lose while `%-of-max` modifiers stay honest. An ability that both `cost`s and `reserve`s the same
pool must afford the two together (the cost is paid first). When the summon dies — or its summoner
does — the reservation is released, restoring the ceiling but **not** refunding what was spent. The
bond runs the other way too: **a dead summoner's creatures vanish with it**, which is what lets
`killAll` still resolve.

A reservation is deliberately *not* scaled by a cost-reducing status: Haste halves `ab.cost`
(`Combat.abilityCost`) but never `ab.reserve` (`Combat.abilityReserve`).

## Knockback and pull

Both are generic (`Combat.knockback` / `Combat.pull`), reachable from any effect. Forced movement
costs the target no turn and no movement, but triggers every trap and hazard it is dragged across.

```lua
effect = function(fx)
    fx.damage(fx.target)
    fx.knockback(fx.target, 2, { amount = fx.amount }) -- 2 tiles, straight back from the caster
end
```

A knockback stopped by the board edge, impassable terrain, or another unit deals `amount` as impact
damage to **everyone involved** — the shoved unit and whatever it slammed into. Direction resolves
to the dominant axis (ties break toward x), matching the 4-directional grid.

`fx.pull(fx.target)` is the inverse: it drags a unit toward the caster until adjacent, re-aiming
each step, and needs a clear line of sight. See `data/items/weapon/mace.lua`,
`data/items/ability/ability_push.lua`, and `ability_pull.lua`.

## The stash, and stealing into it

`player.stash` is an unbounded list of every item nobody is carrying (`Player.addToStash` /
`Player.takeFromStash`); seed it from `data/player.lua`'s `startingStash`. The Party screen
(`ui/panels/party.lua`) shows it as a grid (`ui/pool_grid.lua`) beside each member's 3×3 grid and
moves items either way — or, at a vendor, swaps that pool for the shop's Store.

`fx.steal(fx.target)` lifts one item off a unit. Two blueprint flags shape what a thief finds:

- `noSteal = true` — never taken (a beast's fangs, an elemental's flame fists).
- `stealPriority = N` — the highest is always taken first, ties broken at random (default 0). This
  is how `data/items/utility/utility_decoy.lua` makes itself the obvious thing to grab.

If the thief's own grid is full, a party thief pockets the item into the stash (`combat.stash`,
pointed at `player.stash` by `states/battle.lua`); an enemy thief simply destroys it. See
`data/items/ability/ability_pickpocket.lua` and `tests/steal_spec.lua`.

## Abilities that lie to the combat log

Set `silent = true` on an ability to suppress its default `"X uses Y."` line, then write your own
with `fx.log(kind, text)`. The Decoy uses this to report a plain move, so nothing in the log gives
the trick away. A status can do the same with `hideLog = true` — Invisible would otherwise announce
itself the moment the Decoy grants it. See `data/items/utility/utility_decoy.lua` and
`data/status/status_invisible.lua`.

Note that **any new `fx` helper must be added to all three `fx` tables** in `models/combat.lua`
(`Combat.useItem`, plus the dry runs in `Combat.previewAbility` and `Combat.abilityOutput`). The
dry runs are `pcall`-guarded, so a missing helper doesn't error — it silently blanks the tooltips.

## Tests

Add a `tests/<area>_spec.lua` returning `{ name, fn }` cases; it is auto-discovered. Test the
data/model layer (discovery, filtering, immutability) — not `love.graphics`. Run with
`& "E:\LOVE\lovec.exe" . test`. See `tests/hub_spec.lua`.
