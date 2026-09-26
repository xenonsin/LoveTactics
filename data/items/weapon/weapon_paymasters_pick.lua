-- THE PAYMASTER'S PICK: what he swings while he is still wearing the dwarf (data/characters/
-- character_the_paymaster.lua). Reviewed 2026-09-25/26 ("The Paymaster"): "a weak pick swing". He is the
-- fight's clock and not its muscle -- the gold he throws is the threat, and the blow he lands is only what a
-- paymaster does to somebody who walks up to his table.
--
-- A hammer by family (the pick's point is on the head's far side, and the weight is the same weight), and
-- none of the family's stun: the Delver's iron hammer is the swing a dwarf fights with, and this is not one.
-- Creature kit, no price, noSteal -- it is part of the disguise, and nothing comes off the body but gold.
local Curve = require("models.curve")

return {
    name = "Paymaster's Pick",
    description = "A light pick swing.",
    flavor = "The edge is bright and the haft is not worn. Nobody has dug with it, whatever it looks like.",
    sprite = "assets/items/weapon_paymasters_pick.png",
    type = "weapon",
    class = "creature",
    tags = { "hammer", "impact", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(4, 14), -- the Mandibles' line: the floor of a blow, and the forge's ten on top
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
