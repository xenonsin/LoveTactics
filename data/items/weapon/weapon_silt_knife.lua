-- The Shoalkin's knife: a sliver of something's jaw, bound to a handle of river cane.
--
-- A dagger, so it bleeds -- the family contract (docs/weapons.md), and the floor every knife in the
-- game stands on. What is its own is the second line: IT BITES A SOAKED TARGET HARDER. Silt in an open
-- cut, which is what the fen does to a wound whether or not anybody meant it to.
--
-- WET IS THE MERE'S SHARED VERB, and this is the piece that collects on it. The Fen Lancer soaks the
-- rank behind the one it is skewering, the Tidecaller soaks and then conducts, the shallows soak
-- anybody standing in them (hazard_shallows), and five Shoalkin working a soaked front is a real threat
-- assembled entirely out of parts that already shipped. One faction, one word, four bodies.
--
-- IT DELIBERATELY DOES NOT TUG, and the rejected version is worth recording because it is the better
-- theme and the wrong rung. "Pull the target one tile toward the wielder" reads beautifully on a body
-- that lives in the channel -- and a Shoalkin standing adjacent to a bank tile is standing IN the
-- water, so one tug would drown you, and a pack of five would be chaff that deletes a party member
-- before anybody with a name has taken a turn. Displacement is the elite's verb and stays the elite's
-- verb (data/items/weapon/weapon_undertow_pike.lua).
--
-- WHY IT IS WORTH LOOTING, which is the question the first draft of this item failed: you can make
-- things Wet too. Tidesbreak, the Brackish Lance, a Rain cloud, and any fight taken near water. A knife
-- that is merely cheap is a knife nobody picks up twice.
local Curve = require("models.curve")

return {
    name = "Silt Knife",
    description = "Bleeds. Deals 4 extra damage to a Wet target.",
    flavor = "Something's jawbone, ground down on a stone. The fen provides, if you are not fussy.",
    sprite = "assets/items/silt_knife.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    dropOnly = true,
    dropTier = 3,
    unlockQuests = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(8, 18),
        -- The dagger's own line, carried in the damage call the way an on-hit status must be
        -- (it rides INSIDE fx.damage, never beside it).
        inflicts = { id = "status_bleed" },
        effect = function(fx)
            -- The soaked bonus is a flat addend on the blow rather than a second hit: one number, one
            -- cue, and it reads in the damage preview beside everything else.
            local wet = fx.hasStatus(fx.target, "status_wet")
            fx.damage(fx.target, wet and { amount = (fx.amount or 0) + 4 } or nil)
        end,
    },
}
