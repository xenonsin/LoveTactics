-- DRAGON'S CALL: the Kobold Scale-Priest's once-a-fight summons to the faithful. Round 2 (2026-09-25):
-- the round-1 Tithe-Call hurried the gold-carriers, and with the gold cut it points at what a kobold wants
-- instead -- every kobold on the board takes a free step toward the nearest dragon on its side: onto the
-- brooding tiles, into the Dragon's Eye, or up to the Godling to be eaten.
--
-- A STEP, NOT A WALK: each kobold moves one tile, to whichever open neighbour brings it nearest its
-- dragon, and one already beside a dragon stays put. Creature kit, the priest's own. Cast as support, so
-- the planner scores the board it changes (AI.WEIGHTS.MUTATION); once a fight is the cooldown.
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

return {
    name = "Dragon's Call",
    description = "Once a fight: every kobold on your side takes a free step toward the nearest dragon.",
    flavor = "One note, and every head in the warren turns the same way.",
    sprite = "assets/items/ability_dragons_call.png",
    type = "ability",
    tags = { "rally" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        cooldown = 999, -- once a fight
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            local Combat = require("models.combat")
            local Devotion = require("models.devotion")
            local combat = fx.combat
            for _, u in ipairs((combat and combat.units) or {}) do
                if u.alive and u.side == fx.user.side and Devotion.isDevout(u) then
                    local dragon, gap = Devotion.nearestDragon(combat, u)
                    if dragon and gap > 1 then
                        local best, bestD
                        for _, d in ipairs(DIRS) do
                            local x, y = u.x + d[1], u.y + d[2]
                            if Combat.footprintFree(combat, 1, 1, x, y) then
                                local dist = Combat.cellGap(x, y, dragon)
                                if dist < gap and (not bestD or dist < bestD) then best, bestD = { x, y }, dist end
                            end
                        end
                        if best then fx.teleport(u, best[1], best[2]) end
                    end
                end
            end
        end,
    },
}
