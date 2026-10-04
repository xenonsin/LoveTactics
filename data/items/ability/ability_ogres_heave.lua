-- OGRE'S HEAVE: Sloth's Ogre's drop, on the Barbarian's shelf. Approved 2026-10-04 ("Sloth's Bestiary", slice B):
-- "Lift a body beside you, friend or foe, and throw it up to 4 tiles at a foe. Both take impact."
--
-- Heave's two-stage aim (`throw`): grab the body beside you, then name the foe it goes at -- the landing ray lights
-- the first body in each line, which is the target. Unlike Heave it is thrown AT somebody, not to a tile: the body
-- comes down beside the foe and both take the impact, by the Ogre's own rule (models/sloth_trolls.lua, Trolls.hurl).
-- A landing with no foe on it throws nothing. With no landing at all (a planner's cast) it goes at the farthest foe
-- within 4.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Ogre's Heave",
    description = "Throw a body beside you, friend or foe, up to 4 tiles at a foe. Both take impact.",
    flavor = "The ogre never learned to aim. It only ever learned to pick the one farthest off.",
    sprite = "assets/items/ability_ogres_heave.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "barbarian",
    unlockLevel = 9,
    unstocked = true,
    activeAbility = {
        target = "tile",       -- the body beside you, whichever side it is on
        allowOccupied = true,
        throw = true,          -- two-stage: the grab, then the foe it goes at (Item.isThrow)
        throwRange = 4,
        range = 1,
        minRange = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 12 },
        damage = Curve.ramp(12, 22), -- the ability slot-9 magnitude (tests/balance_spec.lua)
        effect = function(fx)
            local Trolls = require("models.sloth_trolls")
            local Combat = require("models.combat")
            local body = fx.unitAt(fx.tx, fx.ty)
            if not body or body == fx.user then return end
            local target
            if fx.dest then
                target = fx.unitAt(fx.dest.x, fx.dest.y)
                if not (target and target ~= body and target.side ~= fx.user.side) then target = nil end
            else
                target = Trolls.mark(fx.combat, fx.user, body, body)
            end
            if target and Combat.unitGap(body, target) <= Trolls.THROW_REACH then
                Trolls.hurl(fx.combat, fx.user, body, target, fx.amount)
            else
                fx.log("action", "There is no foe there to throw it at.", fx.user)
            end
        end,
    },
}
