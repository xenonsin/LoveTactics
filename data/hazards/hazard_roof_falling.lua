-- THE ROOF COMING DOWN: where Avaritia lands, the cave answers (reviewed 2026-09-25, round 3: "her landing
-- brings down the roof"). Her strafe marks three tiles near where she comes down; each stands ONE TURN -- the
-- telegraph, hostile ground every planner walks out of -- and when it runs out it lands: impact damage and a
-- Stun to whoever is still on it, on both sides, and an empty tile turns to rubble, the mountain's own rock,
-- a wall for the rest of the fight.
--
-- The Deadfall's shape (data/hazards/hazard_deadfall_falling.lua), for the same reason: a hazard's expiry
-- only ever runs live, so no forecast rewrites the ground under the cursor. A tile with a body still on it
-- stays floor -- the rock lands on the body, not in its place.
local DEFAULT_ROCK = 14

return {
    name = "Falling Roof",
    description = "The cave roof coming down. When it lands, a unit here takes impact damage and is Stunned; an empty tile turns to rock.",
    tags = { "earth" },
    duration = 5, -- one turn at Status.TICKS_PER_TURN
    disposition = "hostile",
    onExpire = function(ctx)
        local combat, h = ctx.combat, ctx.hazard
        if not (combat and h) then return end
        local Combat = require("models.combat")
        local under = Combat.unitAt(combat, h.x, h.y)
        if under and under.alive then
            ctx.damage(under, h.amount or DEFAULT_ROCK, { "impact", "physical" })
            if under.alive then require("models.status").apply(combat, under, "status_stun", {}) end
            return
        end
        local tiles = combat.arena and combat.arena.tiles
        local cell = tiles and tiles[h.y] and tiles[h.y][h.x]
        if cell and cell.walkable and not Combat.objectAt(combat, h.x, h.y) then
            local rock = require("models.terrain").get("mountain")
            cell.type = "mountain"
            cell.moveCost = rock.moveCost
            cell.walkable = rock.walkable
            cell.sightCost = rock.sightCost or 0
            cell.bonus = rock.bonus
            cell.tags = rock.tags
            cell.swim, cell.drowns = nil, nil
        end
    end,
}
