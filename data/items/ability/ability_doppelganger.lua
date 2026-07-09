-- Split yourself in two. `fx.copy` builds a duplicate of the caster from its CURRENT state --
-- stats as they stand, wounds and all, plus a fresh copy of everything in its 3x3 grid -- and puts
-- it on the field under the caster's own control. It fights with the caster's kit and it is a
-- second turn in the order.
--
-- What it isn't is durable: `fragile` means any hit at all destroys it, however light. And it can't
-- beget more of itself -- this item is `noCopy`, so the duplicate's grid comes up one slot short
-- (see models/summon.lua).
return {
    name = "Doppelganger",
    description = "Conjure a duplicate of yourself. It fights with your kit, but dies to a single hit.",
    sprite = "assets/items/ability_doppelganger.png",
    type = "ability",
    tags = { "summon", "illusion" },
    noCopy = true,
    activeAbility = {
        name = "Doppelganger",
        target = "tile",
        range = 1,
        speed = 6,
        cost = { stat = "mana", amount = 20 },
        effect = function(fx)
            fx.copy(fx.tx, fx.ty, { fragile = true })
        end,
    },
}
