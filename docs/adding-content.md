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
    x = 620, y = 200, w = 150, h = 100,  -- clickable hotspot in the 800x600 window
    panel = nil,           -- module name under ui/panels/, or nil for the placeholder
    unlockPrestige = 3,    -- locked (dimmed, non-clickable) until prestige >= 3
}
```

This is how **the city grows over time**: give new buildings a higher `unlockPrestige` and they
appear locked, then unlock as the player earns prestige. Positions are in raw 800×600 window
coordinates (see `conf.lua`); place them over the corresponding spot on `assets/hub/city.png`.

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

## Tests

Add a `tests/<area>_spec.lua` returning `{ name, fn }` cases; it is auto-discovered. Test the
data/model layer (discovery, filtering, immutability) — not `love.graphics`. Run with
`& "E:\LOVE\lovec.exe" . test`. See `tests/hub_spec.lua`.
