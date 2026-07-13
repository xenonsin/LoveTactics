-- Crucible rank-2. A cure-all draught: drunk by an ally, it strips every debuff clinging to them --
-- Burn, Poison, Acid, Root, Silence, Disarm, and the rest -- in one swallow. The alchemist's
-- portable answer to the priest's Cure spell (fx.cleanse is the same helper both call), packed into
-- a flask anyone can carry. It touches no buffs: it washes away what was done TO you, and leaves what
-- you did for yourself.
--
-- Marked `support` so its cast previews green, and `restorative` so an Envenom charm won't turn a
-- healing draught into a poison.
return {
    name = "Panacea",
    description = "A cure-all draught. Removes every debuff from an ally.",
    sprite = "assets/items/panacea.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "alchemist",
    price = 100,
    repRank = 2,
    activeAbility = {
        name = "Drink",
        target = "ally", -- includes the user (a unit is its own ally)
        support = true,
        range = 1,
        speed = 3,
        consumesItem = true,
        effect = function(fx)
            fx.cleanse(fx.target)
        end,
    },
}
