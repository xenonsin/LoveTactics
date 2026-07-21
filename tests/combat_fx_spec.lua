-- Tests for the animation controller (ui/combat_fx.lua) -- specifically the one thing about it that
-- is not a matter of taste: WHERE a sprite is drawn while a cue waits its turn.
--
-- The model resolves an exchange atomically, so a knocked-back unit's unit.x/unit.y read as the far
-- tile from the moment the cue is raised, long before the view gets round to playing it. Everything
-- here guards the same invariant: from the instant a shove is known about until its slide finishes,
-- the sprite must be drawn on its ORIGIN tile and then travel once. A regression shows up as the
-- offset reading 0 (the body already standing on the destination -- a teleport) during the wait.

local CombatFx = require("ui.combat_fx")

-- :new() builds two fonts, and love.graphics.newFont refuses to work without a window -- so a headless
-- run gets a stub for the length of construction. Nothing under test draws (the fonts are read only by
-- :drawFloaters), so a placeholder is enough, and stubbing rather than skipping keeps these cases
-- honest: they must actually run in the headless suite, not quietly pass by doing nothing.
local function newFx()
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function() return { getHeight = function() return 18 end } end
    local ok, fx = pcall(CombatFx.new)
    gfx.newFont = real
    assert(ok, "could not construct CombatFx: " .. tostring(fx))
    return fx
end

-- A unit already sitting where the model shoved it, as the view always finds it.
local function shoved(fromX, toX)
    return { x = toX, y = 1, char = { name = "target" } }, fromX
end

-- Pixel offset along x, in tiles, for a 32px grid.
local function offsetTiles(fx, unit)
    local ox = fx:slideOffset(unit, 32)
    return ox / 32
end

-- The offset that means "drawn on the origin tile": the full displacement, backwards.
local function originOffset(fromX, unit) return fromX - unit.x end

return {
    {
        name = "a shove on a deferred beat holds its origin through the gap, then travels once",
        fn = function()
            local fx = newFx()
            local u, fromX = shoved(2, 4) -- knocked two tiles right, as a counter (beat 1)
            fx:ingest({
                { type = "damage", unit = u, amount = 4, beat = 0 },
                { type = "slide", unit = u, fromX = fromX, fromY = 1, hold = true, beat = 1 },
            }, nil)

            -- Immediately, and all through the beat gap, the body must still read as being on tile 2.
            assert(math.abs(offsetTiles(fx, u) - originOffset(fromX, u)) < 0.001,
                "sprite jumped to the destination before its beat played")
            for _ = 1, 20 do fx:update(1 / 60) end -- ~0.33s, still inside BEAT_GAP
            assert(math.abs(offsetTiles(fx, u) - originOffset(fromX, u)) < 0.001,
                "sprite drifted off its origin while the beat was still pending")

            -- Once everything has run out, it is home -- and it got there by travelling, not by
            -- snapping back first: the offset only ever shrinks toward 0.
            local prev = math.abs(offsetTiles(fx, u))
            for _ = 1, 180 do
                fx:update(1 / 60)
                local now = math.abs(offsetTiles(fx, u))
                assert(now <= prev + 0.001, "sprite moved AWAY from its destination mid-slide")
                prev = now
            end
            assert(math.abs(offsetTiles(fx, u)) < 0.001, "slide never finished")
        end,
    },
    {
        name = "a pinned shove stays on its origin however long the cue is withheld",
        fn = function()
            local fx = newFx()
            -- The carried-approach case (states/battle.lua holdLanding): the blow lands in the model
            -- before the attacker's walk is replayed, so the cue can be withheld for seconds.
            local u, fromX = shoved(5, 3) -- knocked two tiles left
            local events = { { type = "slide", unit = u, fromX = fromX, fromY = 1, hold = true, beat = 0 } }
            fx:pinSlides(events)

            for _ = 1, 300 do -- five seconds of approach walk
                fx:update(1 / 60)
                assert(math.abs(offsetTiles(fx, u) - originOffset(fromX, u)) < 0.001,
                    "a pinned sprite left its origin before the cue was ingested")
            end

            -- A pin is a unit standing still: it must never be the reason the turn hand-off waits.
            assert(not fx:busy(), "a pinned slide gated the turn hand-off")

            -- Now the feet stop and the cue plays: it picks up from the origin and lands home.
            fx:ingest(events, nil)
            assert(math.abs(offsetTiles(fx, u) - originOffset(fromX, u)) < 0.001,
                "releasing a pinned slide jumped the sprite")
            for _ = 1, 180 do fx:update(1 / 60) end
            assert(math.abs(offsetTiles(fx, u)) < 0.001, "released slide never finished")
        end,
    },
    {
        name = "a unit's readouts ride its slide instead of waiting on the destination tile",
        fn = function()
            local BattleMap = require("ui.battle_map")
            local fx = newFx()
            local u, fromX = shoved(2, 4)
            fx:ingest({ { type = "slide", unit = u, fromX = fromX, fromY = 1, hold = true, beat = 0 } }, nil)

            -- unitOrigin is pure geometry over cellToPixel + the fx slide, so it can be exercised on a
            -- stand-in rather than a real (graphics-owning) map.
            local map = { size = 32, fx = fx, cellToPixel = function(_, x, y) return x * 32, y * 32 end }
            local function originX() return (BattleMap.unitOrigin(map, u)) end

            -- Mid-shove the bar must hang off the tile the body is still on, not the one it is headed for.
            assert(math.abs(originX() - fromX * 32) < 0.5,
                "readouts sat on the destination tile while the unit was still travelling")
            for _ = 1, 6 do fx:update(1 / 60) end
            assert(originX() < u.x * 32, "readouts arrived ahead of the unit")

            -- And they land with it, not before or after.
            for _ = 1, 120 do fx:update(1 / 60) end
            assert(math.abs(originX() - u.x * 32) < 0.5, "readouts never settled on the destination tile")
        end,
    },
    {
        name = "an unheld shove on beat 0 still plays straight away",
        fn = function()
            local fx = newFx()
            -- The plain case (a mace hit with no approach and no counter) must not have been slowed
            -- down by any of the above: it holds SHOVE_HOLD for its damage number, then goes.
            local u, fromX = shoved(1, 2)
            fx:ingest({ { type = "slide", unit = u, fromX = fromX, fromY = 1, hold = true, beat = 0 } }, nil)
            assert(math.abs(offsetTiles(fx, u) - originOffset(fromX, u)) < 0.001, "did not start on its origin")
            for _ = 1, 60 do fx:update(1 / 60) end -- one second covers SHOVE_HOLD + a one-tile slide
            assert(math.abs(offsetTiles(fx, u)) < 0.001, "a plain shove had not landed after a second")
        end,
    },
}


