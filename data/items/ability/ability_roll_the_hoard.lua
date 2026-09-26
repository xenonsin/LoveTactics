-- ROLL THE HOARD: the Brood Queen's puzzle, and the one thing on floor five that is fatal to get wrong.
-- Reviewed 2026-09-25 ("The Coin-Eaters"): "I want the fight's mechanic to be a sort of puzzle, if you
-- fail the puzzle it's fatal" -- settled as the Rolling Hoard, fatal meaning downed in the lane.
--
-- THE CLOCK is her Hoard (status_hoard): gold her scarabs roll into her (Scarab.roll). At THRESHOLD she
-- winds up -- the lane is marked a turn ahead, which is the whole of the warning -- and rolls the whole
-- hoard down it. EVERYTHING in the lane is downed outright, hers included: the body is taken to 0 and
-- falls under the ordinary revive rules, never out of the game. The hoard lands as one heap where the
-- lane ends, so the next hoard is already on the floor.
--
-- THE SOLVE is on the board: loot heaps before the scarabs reach them, kill the rollers, stand a body in
-- a lane so a heap stops short of her, or read the marked lane and get out of it. Where the heaps lie
-- decides which lanes matter, so the puzzle is new on every board the floor re-arms.
local Status = require("models.status")

local THRESHOLD = 20
local LANE = 8

return {
    name = "Roll the Hoard",
    description = "At 20 Hoard, winds up and rolls it down an 8-tile lane; everything in the lane is downed.",
    flavor = "She has been saving. Everyone standing in the way has been saving too, and it will not help.",
    sprite = "assets/items/ability_roll_the_hoard.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "impact", "physical" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 5,
        windup = 5, -- one turn: the lane is committed and marked, and everyone gets to read it
        cost = { stat = "stamina", amount = 6 },
        aoe = { shape = "line", length = LANE },
        -- The lane is aimed by the tile beside her it starts through, and those four are empty more often
        -- than not -- so the planner is told about them (models/ai.lua's aiAims) rather than left to find
        -- the lanes only where a body happens to stand next to her.
        aiAims = function(_, unit)
            return { { x = unit.x + 1, y = unit.y }, { x = unit.x - 1, y = unit.y },
                     { x = unit.x, y = unit.y + 1 }, { x = unit.x, y = unit.y - 1 } }
        end,
        ai = { priority = "urgent", act = "cast" },
        usable = function(unit)
            if Status.stacksOf(unit, "status_hoard") < THRESHOLD then
                return false, "The hoard is not big enough"
            end
            return true
        end,
        effect = function(fx)
            local user = fx.user
            local gold = Status.stacksOf(user, "status_hoard")
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= user and u.alive then
                    local hp = u.char and u.char.stats and u.char.stats.health
                    local cur = (hp and hp.current) or 0
                    if cur > 0 then fx.flatDamage(u, cur, { "impact" }) end
                end
            end
            fx.clearStatus(user, "status_hoard")
            -- The hoard comes to rest at the far end of the lane: the last open tile it covered.
            local last
            local tiles = fx.combat and fx.combat.arena and fx.combat.arena.tiles
            for _, c in ipairs(fx.aoeCells() or {}) do
                local cell = tiles and tiles[c.y] and tiles[c.y][c.x]
                if cell and cell.walkable and not fx.unitAt(c.x, c.y) then last = c end
            end
            if last and gold > 0 then fx.placeHazard(last.x, last.y, "hazard_coin_heap", { amount = gold }) end
        end,
    },
}
