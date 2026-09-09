-- The Demon Champion's own hands, and they exist because of ONE TAG.
--
-- She used to swing data/items/weapon/weapon_great_claws.lua -- the bear's natural weapon, the heavy
-- end of the beast shelf. That was fine while the two of them only wanted the same NUMBERS, and it
-- stopped being fine the moment the demons needed to burn: every demon on the sweep spits hellfire
-- (weapon_cinder_spit.lua, ability_demon_brimstone.lua) and the thing that WALKS UP to you was the one
-- attack in the bestiary that did not, so the elemental coats had nothing to drink off a demon and a
-- Salamander Hide read as a dead item in the fight it was found for.
--
-- Tagging Great Claws would have set the DIRE BEAR on fire. That shape is a hunter wearing it
-- (data/characters/character_dire_bear.lua), not a thing anyone fights, and nothing about it is
-- infernal -- so the shared blueprint splits here rather than one of its two owners lying about what
-- it is. Same numbers as the claws it was cut from, on purpose: this is a re-tag, not a rebalance.
--
-- The element is added; the CHANNEL is not moved. `magical` is what routes a hit through
-- magicDamage/magicDefense (models/combat.lua), and a boss's claws landing on Magic Defense instead of
-- armour would walk straight past every coat and shield the party is wearing -- a far larger change
-- than making them burn. So: physical blow, fire element.
--
-- `natural`, `noSteal` and sold by nobody, like every creature's body: the family tag carries no shared
-- contract of its own (see Item.ARCHETYPES) -- what a creature's body does is the creature's business.
local Curve = require("models.curve")

return {
    name = "Infernal Claws",
    description = "Rends an adjacent foe, and the wound burns.",
    flavor = "She does not carry the fire the way the little ones do. She simply is not cool to the touch.",
    sprite = "assets/items/great_claws.png", -- placeholder until its own art exists (as demon_cleave does)
    type = "weapon",
    class = "creature",
    dropTier = 5,
    tags = { "natural", "slash", "physical", "melee", "fire" },
    noSteal = true, -- a pickpocket does not get a hand into a demon's
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7, -- ponderous: she swings once where a swordsman swings twice
        cost = { stat = "stamina", amount = 12 },
        damage = Curve.ramp(16, 28),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
