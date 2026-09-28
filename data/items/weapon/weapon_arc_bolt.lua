-- ARC BOLT: the Arc's natural weapon, and the Thunderhead's (models/storm.lua; "Fire, Lightning, and Dirty
-- Thunder", 2026-09-27). A ranged bolt that FORKS: to the nearest other body within 2 of the one it struck, friend or
-- foe, for half, and once more from there (Storm.fork). Spreading out answers it; Wrath's mobs make that hard.
--
-- Range 4 and a clear line, on a board whose lava hides nobody: a body on the far side of a flow is safe from it
-- only by walking the long way round. It carries Storm-Kin (the fusion), which is inert on the storm itself.
-- `noSteal`: the storm is not yours to take.
local Curve = require("models.curve")

return {
    name = "Arc Bolt",
    description = "A bolt that forks to the nearest other body within 2, friend or foe, for half -- twice.",
    flavor = "It does not choose. It goes where the air is thinnest, which is usually through somebody.",
    sprite = "assets/items/weapon_arc_bolt.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "lightning", "magical", "ranged" },
    noSteal = true,
    traits = { "trait_storm_kin" },
    forks = 2,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            require("models.storm").fork(fx, t, 2)
        end,
    },
}
