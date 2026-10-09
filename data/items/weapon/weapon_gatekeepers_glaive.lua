-- GATEKEEPER'S GLAIVE: the Archon Warden's blow (data/characters/character_archon_warden.lua; "The Crown's
-- Bestiary", slice A, 2026-10-09). Its own blows shove the struck body 1 tile back out -- the shove folded into the
-- blow (opts.knockback, the Iron Mace's way), so the body is pushed out of the doorway the Warden is holding.
--
-- An Archon is not a demon: no fire rides it. The body's own and never loot; the Warden pays the Warden's Post.
local Curve = require("models.curve")

return {
    name = "Gatekeeper's Glaive",
    description = "Strikes an adjacent foe. Knockback 1.",
    flavor = "It does not need to win. It needs you on the other side of the line.",
    sprite = "assets/items/weapon_gatekeepers_glaive.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            fx.damage(fx.target, { knockback = { distance = 1, amount = fx.amount } })
        end,
    },
}
