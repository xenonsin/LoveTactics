-- Bolas: a thrown weight that wraps a runner's legs. Almost no damage, then Root (data/status/root.lua)
-- -- the target burns its turn going nowhere. The hunter half of the Poacher (rogue x hunter): it sets
-- up the Poacher's Kris, which bites half again as deep into a foe that cannot flinch away. Thrown, not
-- a bow shot, so it needs no weapon beside it -- the snare IS the tool.
--
-- The weight is nearly nothing ON PURPOSE, which is why it sits under its slot's number with a waiver
-- in Balance.MAGNITUDE_WAIVERS. What is bought here is the Root, and the Poacher's shelf is what cashes
-- it. Given a slot-10 blow on top, a weaponless Root at speed 4 would simply be the better Pinning Shot
-- and the discipline would stop having two halves.
local Curve = require("models.curve")

return {
    name = "Bolas",
    description = "Deals damage and inflicts Root.",
    flavor = "The Lodge tracks. The Undercroft collects. This is the knot where the two trades meet.",
    sprite = "assets/items/ability_bolas.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "poacher", -- rogue x hunter; the Snare-execute mechanic's first stock
    price = 660,
    unlockQuests = 7,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(6, 16), -- light: the snare is the payload, not the weight
        effect = function(fx)
            -- Root rides the blow (opts.inflicts) rather than landing on the line after it, so a
            -- guardian who takes the hit in the target's place (Sworn Aegis, Oathward) is the one left
            -- pinned -- the whole snare follows the body the blow lands on, not the body it was aimed at.
            fx.damage(fx.target, { inflicts = "status_root" })
        end,
    },
}
