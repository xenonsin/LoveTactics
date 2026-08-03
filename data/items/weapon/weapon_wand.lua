-- The wand archetype: ranged magical damage, the magical counterpart to data/items/weapon/bow.lua
-- (docs/weapons.md). The `magical` tag routes the hit through the wielder's Magic Damage and the
-- target's Magic Defense, so where a bow punishes light armor a wand punishes the unwarded.
--
-- The one thing it does NOT copy from the bow is `minRange`: a bow needs room to draw, a wand needs
-- only a direction, so it fires point-blank as happily as across the board. That is the wand's whole
-- claim over a bow -- less damage, but never a dead zone to be walked into.
--
-- A mage's basic attack: it spends mana rather than stamina, so it competes with the mage's spells
-- for the scarce pool. The Arcanum's entry-rank weapon.
local Curve = require("models.curve")

return {
    name = "Wand",
    description = "Looses a bolt of force.",
    flavor = "The Arcanum's first focus: worked yew, and a great deal of condescension.",
    sprite = "assets/items/wand.png",
    type = "weapon",
    tags = { "wand", "magical", "ranged" },
    class = "mage",
    price = 80,
    unlockQuests = 0,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line: terrain cover blocks the shot
        speed = 3,
        cost = { stat = "mana", amount = 4 }, -- mana, not stamina: it competes with the mage's spells
        damage = Curve.ramp(5, 15), -- damage = power + the wielder's Magic Damage, minus Magic Defense
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
