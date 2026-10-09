-- HELLFIRE RING: the Balor's (data/characters/character_balor.lua; "The Crown's Bestiary", slice B, approved
-- 2026-10-09). A telegraphed wind-up, and then every tile within 2 of the body burns. The answer is the telegraph:
-- step out of the ring when it winds up. Both sides are caught; a ring does not ask whose it is.
--
-- A self-cast quoting range 0 whose footprint is the ring around the WHOLE 2x2 body (models/crown_demons.lua's
-- ringCells), so the telegraph and the blast are the same cells on every side.
local Curve = require("models.curve")

local RADIUS = 2

return {
    name = "Hellfire Ring",
    description = "Winds up, then burns every tile within 2 of it.",
    flavor = "The air goes still first. Anyone who has seen one before is already running.",
    sprite = "assets/items/ability_hellfire_ring.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "creature",
    bound = true,
    noSteal = true,
    activeAbility = {
        target = "self",
        support = false,
        range = 0,
        speed = 4,
        windup = 5, -- one turn: the ring is drawn, and then it burns
        cooldown = 15,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(14, 26),
        aoe = {
            cells = function(_, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                return require("models.crown_demons").ringCells(unit, RADIUS)
            end,
        },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive then fx.damage(u) end
            end
        end,
    },
}
