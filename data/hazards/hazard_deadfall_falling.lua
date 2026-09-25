-- A sprung Deadfall's rock, coming down (data/hazards/hazard_deadfall_rig.lua). It stands ONE TURN -- the
-- telegraph, hostile ground every planner walks out of -- and when it runs out (onExpire) it lands: impact
-- damage to whoever is still standing on the tile, on BOTH sides (rock is not particular), and the tile
-- turns to rough ground.
--
-- THE LANDING IS ON onExpire FOR THE SAME REASON Cave-In is a status: a hazard's expiry only ever runs live,
-- so no forecast, hover or dry run can rewrite the ground under the cursor. On the Goldvein Deeps the floor
-- is rough already and the rubble changes nothing; laid anywhere else, it slows the ground it fell on.
local DEFAULT_ROCK = 12

return {
    name = "Falling Rock",
    description = "A deadfall coming down. When it lands, whoever stands here takes impact damage, and the ground turns rough.",
    tags = { "earth" },
    duration = 5, -- one turn at Status.TICKS_PER_TURN
    disposition = "hostile",
    onExpire = function(ctx)
        local combat, h = ctx.combat, ctx.hazard
        if not (combat and h) then return end
        local Combat = require("models.combat")
        local under = Combat.unitAt(combat, h.x, h.y)
        if under and under.alive then ctx.damage(under, h.amount or DEFAULT_ROCK, { "impact", "physical" }) end
        local tiles = combat.arena and combat.arena.tiles
        local cell = tiles and tiles[h.y] and tiles[h.y][h.x]
        if cell and cell.walkable and cell.type ~= "rough" then
            local rough = require("models.terrain").get("rough")
            cell.type = "rough"
            cell.moveCost = rough.moveCost
            cell.walkable = rough.walkable
            cell.sightCost = rough.sightCost or 0
            cell.bonus = rough.bonus
            cell.tags = rough.tags
        end
    end,
}
