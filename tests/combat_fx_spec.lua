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

    -- ---------------------------------------------------------------------------
    -- Ranged blows fly: a shot from >=2 tiles becomes a projectile, and its wound is held back until
    -- the bolt lands. This reuses the exact deferral the shove tests above exercise (pending / hold /
    -- busy), so a regression here is a regression in the same seam. A fake burst controller stands in
    -- for ui/burst_fx.lua -- the invariant is the TIMING, not the picture.
    -- ---------------------------------------------------------------------------
    {
        name = "a ranged blow launches a bolt and holds the victim until it lands",
        fn = function()
            local fx = newFx()
            local flights, strikes = 0, 0
            fx.bursts = {
                flight = function(_, _, _, _, _, _) flights = flights + 1; return 0.2 end,
                strike = function() strikes = strikes + 1 end,
                support = function() end,
            }
            local attacker = { x = 1, y = 1, char = { name = "shooter" } }
            local victim = { x = 5, y = 1, alive = true, char = { name = "mark" } }
            fx:ingest({ { type = "damage", unit = victim, attacker = attacker, amount = 3, beat = 0,
                tags = { "fire" } } }, attacker)

            -- The bolt is away, but nothing has struck yet: the victim is held and the turn cannot pass.
            assert(flights == 1, "no bolt was launched for a blow from across the board")
            assert(strikes == 0, "the impact fired before the bolt arrived")
            assert(#fx.floaters == 0, "the damage number showed before the bolt arrived")
            assert(fx:awaiting(victim), "the victim was not held while the bolt was in flight")
            assert(fx:busy(), "the turn handed off while a bolt was still in the air")

            -- Once the flight time elapses the wound lands: the number floats, the impact bursts, the
            -- hold releases.
            for _ = 1, 20 do fx:update(1 / 60) end -- 0.33s > 0.2 flight
            assert(strikes == 1, "the impact never fired when the bolt landed")
            assert(#fx.floaters >= 1, "no damage number after the bolt landed")
            assert(not fx:awaiting(victim), "the victim stayed held after the bolt landed")
        end,
    },
    {
        name = "a melee blow does not fly -- it lands on the same frame",
        fn = function()
            local fx = newFx()
            local flights = 0
            fx.bursts = {
                flight = function() flights = flights + 1; return 0.2 end,
                strike = function() end, support = function() end,
            }
            local attacker = { x = 1, y = 1, char = { name = "swinger" } }
            local victim = { x = 2, y = 1, alive = true, char = { name = "mark" } }
            fx:ingest({ { type = "damage", unit = victim, attacker = attacker, amount = 3, beat = 0,
                tags = { "slash" } } }, attacker)
            assert(flights == 0, "an adjacent blow must not launch a projectile")
            assert(#fx.floaters >= 1, "a melee damage number should show at once")
            assert(not fx:awaiting(victim), "a melee victim should never be held")
        end,
    },
    {
        name = "a mace's own shove is not a shooting distance",
        fn = function()
            local fx = newFx()
            local flights, hitX = 0, nil
            fx.bursts = {
                flight = function() flights = flights + 1; return 0.2 end,
                strike = function(_, x) hitX = x end,
                support = function() end,
            }
            -- The Iron Mace: struck from the next tile over, and the same blow threw the body two
            -- further. The model resolved both at once, so the victim already READS as four tiles out.
            local attacker = { x = 1, y = 1, char = { name = "swinger" } }
            local victim = { x = 4, y = 1, alive = true, char = { name = "mark" } }
            fx:ingest({
                { type = "damage", unit = victim, attacker = attacker, amount = 9, beat = 0,
                  tags = { "mace", "impact", "physical", "melee" } },
                { type = "slide", unit = victim, fromX = 2, fromY = 1, hold = true, beat = 0 },
            }, attacker)
            assert(flights == 0, "a mace fired a projectile: its own knockback was read as a shot")
            assert(hitX == 2, "the impact burst landed on the knocked-back tile, not the struck one")
            assert(#fx.floaters >= 1, "the mace's damage number should show at once, not on an arrival")
        end,
    },
    {
        name = "a bolt is aimed where the body IS, not where its shove is about to put it",
        fn = function()
            local fx = newFx()
            local shotAt, hitX = nil, nil
            fx.bursts = {
                flight = function(_, _, _, toX) shotAt = toX; return 0.2 end,
                strike = function(_, x) hitX = x end,
                support = function() end,
            }
            -- A ranged blow that also shoves (the Tidesbreak's line). The bolt must stop on the tile
            -- the target is standing on -- which is where the sprite is pinned -- and only then is the
            -- body thrown; a bolt aimed at unit.x flies past it to the far end before the hit lands.
            local attacker = { x = 1, y = 1, char = { name = "shooter" } }
            local victim = { x = 7, y = 1, alive = true, char = { name = "mark" } }
            fx:ingest({
                { type = "damage", unit = victim, attacker = attacker, amount = 6, beat = 0,
                  tags = { "bow", "pierce", "physical", "ranged" } },
                { type = "slide", unit = victim, fromX = 5, fromY = 1, hold = true, beat = 0 },
            }, attacker)
            assert(shotAt == 5, "the bolt was aimed at the end of the knockback, overshooting the target")
            assert(math.abs(offsetTiles(fx, victim) - originOffset(5, victim)) < 0.001,
                "the body left its tile while the bolt was still in the air")

            for _ = 1, 20 do fx:update(1 / 60) end -- 0.33s > the 0.2 flight
            assert(hitX == 5, "the impact burst fired on the destination tile rather than the struck one")
            assert(#fx.floaters >= 1, "no damage number when the bolt landed")
        end,
    },
    {
        name = "without a burst controller a ranged blow still resolves at once (headless model tests)",
        fn = function()
            local fx = newFx() -- fx.bursts is nil
            local attacker = { x = 1, y = 1, char = { name = "shooter" } }
            local victim = { x = 6, y = 1, alive = true, char = { name = "mark" } }
            fx:ingest({ { type = "damage", unit = victim, attacker = attacker, amount = 3, beat = 0,
                tags = { "fire" } } }, attacker)
            -- No controller to defer against: the exchange plays exactly as it did before flights existed.
            assert(#fx.floaters >= 1, "a blow with no burst controller should resolve immediately")
            assert(not fx:awaiting(victim), "nothing should be held when there is no bolt to wait on")
        end,
    },
}


