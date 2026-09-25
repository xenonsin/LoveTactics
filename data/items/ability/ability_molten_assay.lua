-- MOLTEN ASSAY: the Dwarf Goldsmith's bolt (round 3, 2026-09-24, on Keno's note "needs attacks of its
-- own"). A pour of molten gold at range 4 -- the pour the dwarves of Erebor tried on Smaug -- that lands
-- +4 harder on a Gilded body (data/status/status_gilded.lua). It pays off the gilding without making the
-- gilding worse. Creature kit: the Goldsmith's forge, not a piece the company loots.
local Curve = require("models.curve")

local GILDED_BONUS = 4

return {
    name = "Molten Assay",
    description = "A bolt of molten gold. Deals 4 more to a Gilded target.",
    flavor = "Gold runs at a heat that stone does not. The dwarves learned this from the stone.",
    sprite = "assets/items/ability_molten_assay.png",
    type = "ability",
    tags = { "magical", "fire" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 4,
        requiresSight = true,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local extra = fx.hasStatus(t, "status_gilded") and GILDED_BONUS or 0
            fx.damage(t, { amount = (fx.amount or 0) + extra })
        end,
    },
}
