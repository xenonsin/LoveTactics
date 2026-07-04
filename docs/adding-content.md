# Adding content

All game content is data-driven: drop a Lua file into the matching `data/` folder and
`models/registry.lua` picks it up by filename (no registration). Blueprints are read-only —
models copy them into runtime state.

## Add a quest

Create `data/quests/<id>.lua`:

```lua
return {
    name = "Bandit Ambush",
    description = "Raiders have blocked the north road. Clear them out.",
    difficulty = "Easy",
    rewardGold = 50,
    requiredPrestige = 1, -- appears once the player's prestige reaches this
}
```

It shows up automatically on the Quest Board for players whose prestige meets
`requiredPrestige` (`Quest.available` in `models/quest.lua`).

## Add a building to the hub city

Create `data/buildings/<id>.lua`:

```lua
return {
    name = "Guild Hall",
    order = 5,             -- sort + keyboard/gamepad nav order
    x = 980, y = 200, w = 200, h = 130,  -- clickable hotspot in the 1280x720 logical space
    panel = nil,           -- module name under ui/panels/, or nil for the placeholder
    unlockPrestige = 3,    -- locked (dimmed, non-clickable) until prestige >= 3
}
```

This is how **the city grows over time**: give new buildings a higher `unlockPrestige` and they
appear locked, then unlock as the player earns prestige. Positions are in the 1280×720 logical
coordinate space (see `scale.lua`), which is letterbox-scaled to the real window; place them
over the corresponding spot on `assets/hub/city.png`.

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
(a `startingItems` list is optional for foes):

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
}
```

## Scale a combat encounter's roster

A `combat` / `elite` encounter fields its enemies in the battle arena via `composition`, a
`function(ctx)` that returns a list of `data/characters` ids and **scales with player prestige**
(`ctx = { prestige, biome, quest }`), mirroring the dynamic `weight`:

```lua
composition = function(ctx)
    local p = ctx.prestige or 1
    local list = {}
    for i = 1, 2 + math.floor(p / 2) do list[i] = "wolf_grunt" end
    if p >= 3 then list[#list + 1] = "wolf_alpha" end -- an alpha joins at higher renown
    return list
end,
```

A quest's **objective** battle is authored on `map.objective` — its own `composition` plus a win
condition `win = { type = "killAll" | "survive" | "assassinate", turns = N, target = "<id>" }`
(`win` omitted ⇒ `killAll`):

```lua
objective = {
    name = "The Warlord",
    composition = function(ctx) return { "warlord", "champion", "champion" } end,
    win = { type = "assassinate", target = "warlord" },
},
```

Encounters without a `composition` fall back to a single generic foe.

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
        -- ... "rough" = move penalty, "obstacle" = blocked ...
    },
    partySpawns = { { x = 2, y = 8 }, { x = 4, y = 8 }, { x = 6, y = 8 } },
    enemySpawns = { { x = 2, y = 1 }, { x = 4, y = 1 }, { x = 6, y = 1 } },
}
```

The fastest way to author one: in a battle press **F5** (dev-only debug save) to serialize the
current arena to `data/arenas/<biome>_<timestamp>.lua`, then rename and hand-edit it. See
`data/arenas/forest_01.lua`.

## Tests

Add a `tests/<area>_spec.lua` returning `{ name, fn }` cases; it is auto-discovered. Test the
data/model layer (discovery, filtering, immutability) — not `love.graphics`. Run with
`& "E:\LOVE\lovec.exe" . test`. See `tests/hub_spec.lua`.
