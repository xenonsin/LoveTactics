-- LASH OF FLAME: the Thing Under the Seam's reach (character_deep_bane). Three tiles of burning whip, and
-- what it catches comes the WHOLE WAY to the body's side, Burning -- the Pull's haul (Combat.pull, the verb
-- ability_pull and the toad's tongue ride) at a longer reach, on a weapon rather than a cast.
--
-- THE BLOW FIRST, THEN THE HAUL, as the Gathering Bell has it: the Burn rides inside the damage call, so
-- a lash that missed caught nothing and burned nothing (docs/accuracy.md), and a corpse is not dragged.
-- A body dragged through the trail the thing leaves behind takes that fire too (a pull walks it through
-- Combat.enterTile), which is most of what makes the pull dangerous.
--
-- ACROSS THE GAP. Past half health the floor falls away round the body (What Was Sleeping), and an
-- ordinary haul stops dead at the edge of ground nobody can stand on. The lash does not: when the haul
-- has stopped short against open ground -- terrain nothing walks but anything can see across -- the body
-- is carried OVER it to the nearest free tile beside the thing (fx.teleport, gliding, so it is seen
-- crossing). A body or a wall in the way still stops it, exactly as it stops a Pull. That is the design's
-- own line: after the break, the lash is how you get to it.
--
-- A demon's blow: `physical` with `fire` ADDED, never moved to `magical` (docs/bestiary.md). A natural
-- weapon: no class shelf, no price, noSteal.
local Curve = require("models.curve")

-- Where the haul would have stepped next from (x, y) toward the puller: Combat.pull's own dominant-axis
-- rule, restated because that helper is local to the engine.
local function nextStep(ux, uy, x, y)
    local dx, dy = ux - x, uy - y
    if math.abs(dx) >= math.abs(dy) then
        return x + ((dx > 0 and 1) or (dx < 0 and -1) or 0), y
    end
    return x, y + ((dy > 0 and 1) or -1)
end

return {
    name = "Lash of Flame",
    description = "Lashes a foe up to 3 tiles away, Burns it and hauls it to its side, over any gap.",
    flavor = "The dwarves heard it before they saw it. By then the distance had stopped meaning anything.",
    sprite = "assets/items/weapon_lash_of_flame.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "fire", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 5,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            local t = fx.target
            local dealt = fx.damage(t, { inflicts = "status_burn" })
            if not (dealt and dealt > 0 and t.alive) then return end
            fx.pull(t)
            if not t.alive then return end

            -- Stopped short? Only open ground carries it over; a body, an object or rock stops it.
            local Combat = require("models.combat")
            local user = fx.user
            if Combat.unitGap(user, t) <= 1 then return end
            local tiles = fx.combat and fx.combat.arena and fx.combat.arena.tiles
            if not tiles then return end
            local sx, sy = nextStep(user.x, user.y, t.x, t.y)
            local step = tiles[sy] and tiles[sy][sx]
            if not step or step.walkable or (step.sightCost or 0) ~= 0 then return end
            if fx.unitAt(sx, sy) or fx.objectAt(sx, sy) then return end

            -- The free tile beside the body nearest where the victim hangs, first in reading order on a tie.
            local best, bestD
            local w, h = user.w or 1, user.h or 1
            for y = user.y - 1, user.y + h do
                for x = user.x - 1, user.x + w do
                    local cell = tiles[y] and tiles[y][x]
                    if cell and cell.walkable and Combat.cellGap(x, y, user) == 1
                        and not fx.unitAt(x, y) and not fx.objectAt(x, y) then
                        local d = math.abs(x - t.x) + math.abs(y - t.y)
                        if not bestD or d < bestD then best, bestD = { x = x, y = y }, d end
                    end
                end
            end
            if best then fx.teleport(t, best.x, best.y, { glide = true }) end
        end,
    },
}
