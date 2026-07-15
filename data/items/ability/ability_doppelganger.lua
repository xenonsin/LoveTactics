-- Split yourself in two. `fx.copy` builds a duplicate of the caster from its CURRENT state --
-- stats as they stand, wounds and all, plus a fresh copy of everything in its 3x3 grid -- and puts
-- it on the field under the caster's own control. It fights with the caster's kit and it is a
-- second turn in the order.
--
-- What it isn't is durable: `fragile` means any hit at all destroys it, however light. And it can't
-- beget more of itself, twice over: this item is `noCopy`, so the duplicate's grid comes up one slot
-- short (see models/summon.lua), and the caster may not split again while the first double stands
-- (Combat.activeSummon -- one summon per item, whatever it summons).
--
-- Mage gear, and it belongs on that shelf for a reason: the Arcanum's sin is Pride, and this is a
-- spell whose answer to every problem is a second copy of the caster. Its opposite number sits in the
-- Crucible -- the Philosopher's Stone, which copies SOMEONE ELSE. The same mechanic turned outward is
-- Envy. See docs/story.md.
return {
    name = "Doppelganger",
    description = "Conjure a duplicate of yourself. It fights with your kit, but dies to a single hit.",
    sprite = "assets/items/ability_doppelganger.png",
    type = "ability",
    tags = { "summon", "illusion" },
    class = "mage",
    price = 350,
    repRank = 3,
    noCopy = true,
    activeAbility = {
        target = "tile",
        range = 1,
        speed = 6,
        cost = { stat = "mana", amount = 20 },
        effect = function(fx)
            fx.copy(fx.tx, fx.ty, { fragile = true })
        end,
    },
}
