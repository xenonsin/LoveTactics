-- THE UNCLOSING SPEAR: the shaft that did not kill the boar, still in the boar.
--
-- A spear, so it skewers a two-tile line and its status lands on the FAR tile (docs/weapons.md's spear
-- contract: the point reaches past the near body to the rank behind). Its extra over the iron is that
-- the far tile is left Unclosing -- nothing heals that body by any means while it holds
-- (data/status/status_unclosing_wound.lua; Combat.applyHeal refuses at the top).
--
-- WHICH IS A DIFFERENT WEAPON FROM weapon_unclosing_edge, and the difference is the whole reason the
-- spear family exists. The edge puts the wound on what it hits. This puts it on the body BEHIND what it
-- hits -- the rank you cannot reach, which is exactly where an enemy line keeps the thing being healed.
-- Thrust through the front rank and the priest behind it stops being a priest for two turns. The status
-- is the same word deliberately (one word per mechanic); the delivery is what was bought.
--
-- WHY A BOAR HANDS IT OVER. It is not a body part and it never was -- docs/drops.md is firm that a body
-- part is never on a drops list, and this is the opposite case: gear the animal is CARRYING, in the most
-- literal sense available. Somebody went out after it with the right weapon and did not come back, and
-- the spear went on living in the boar. That is also character_the_unseeing.lua's whole premise at a
-- smaller scale (utility_the_iron_in_him), which is the point: the lord is what happens when the shaft
-- is never worked out, and this is every other boar on the road carrying the same story untold.
local Curve = require("models.curve")

return {
    name = "Unclosing Spear",
    description = "Skewers a two-tile line. The far tile cannot be healed.",
    flavor = "It has been in there long enough to be part of the animal. It comes out the way it went in.",
    sprite = "assets/items/weapon_unclosing_spear.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2, -- a two-handed polearm, as every spear is
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS rather than with the spear family's root house, and
    -- that placement is doing two jobs. It is the right taxonomy -- a wound that will not close is the
    -- plague knight's entire argument, where the knight's is the line and the shield. It is also what
    -- makes an eleventh spear legal: tests/weapon_spec.lua holds every shoppable family to exactly ten,
    -- and Class.isEarned excludes a discipline's deep cut from that roster (the family of ten is the
    -- OPEN RACK, not a census of everything that has ever been a spear).
    class = "plague_knight",
    -- Its grade rank, which is what models/balance.lua measures the magnitude against. A found weapon
    -- keeps both its class and its rung; left at 0 this reads as a slot-0 item swinging a 15 and fails
    -- the ladder outright.
    unlockQuests = 8,
    -- THE BOAR'S OWN CHASE, and deep because the spear is worth it rather than to make it rare. Its
    -- list-mate (armor_bristlehide, rank 3) is the piece a company meets in its first week; this is the
    -- one they are still hoping for in their fifth. Reachable because a boar is ungated and keeps
    -- turning up at depth -- the Unseeing's whole clan is boars (data/items/ability/ability_the_call.lua).
    dropTier = 8,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(15, 25), -- a shade under the iron spear's: the wound is the rest
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            -- The spear convention: the status lands on the FAR tile -- the aimed cell continued one
            -- step along the thrust. Read off the thrust rather than off facing, exactly as
            -- weapon_boar_spear reads it, so the two spears cannot disagree about where "far" is.
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local farX, farY = fx.tx + dx, fx.ty + dy
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                if u.alive and u.x == farX and u.y == farY then
                    fx.applyStatus(u, "status_unclosing_wound")
                end
            end
        end,
    },
}
