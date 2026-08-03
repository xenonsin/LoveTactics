-- Bolas: a thrown weight that wraps a runner's legs. Modest damage, then Root (data/status/root.lua) --
-- the target burns its turn going nowhere. The hunter half of the Poacher (rogue x hunter): it sets up
-- the Poacher's Kris, which bites half again as deep into a foe that cannot flinch away. Thrown, not a
-- bow shot, so it needs no weapon beside it -- the snare IS the tool.
local Curve = require("models.curve")

return {
    name = "Bolas",
    description = "Deals damage and inflicts Root.",
    flavor = "The Lodge tracks. The Undercroft collects. This is the knot where the two trades meet.",
    sprite = "assets/items/ability_bolas.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    discipline = "poacher", -- rogue x hunter; the Snare-execute mechanic's first stock
    price = 240,
    unlockQuests = 3,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(3, 13),
        effect = function(fx)
            -- Root rides the blow (opts.inflicts) rather than landing on the line after it, so a
            -- guardian who takes the hit in the target's place (Sworn Aegis, Oathward) is the one left
            -- pinned -- the whole snare follows the body the blow lands on, not the body it was aimed at.
            fx.damage(fx.target, { inflicts = "status_root" })
        end,
    },
}
