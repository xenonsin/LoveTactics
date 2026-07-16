-- The apprentice's cure-all: everything the Panacea does, for yourself and yourself only.
--
-- Deliberately the SAME effect as data/items/consumable/panacea.lua rather than a weaker one, because
-- the interesting axis between them isn't potency, it's REACH. The Panacea is a rank-2 flask you press
-- into someone else's hand -- it answers the fight's real problem, which is that the person who most
-- needs a cure (rooted, silenced, charmed, asleep) is usually the person who can no longer reach for
-- one. This vial answers only your own trouble, and only on your own turn. A stunned ally is worth a
-- Panacea; a burning one is worth this.
--
-- That split is what lets it sit at rank 1 for a third of the price without undercutting the shelf
-- above it: the cheap answer to a debuff you can still act through, so a new alchemist has a real
-- cleanse from the first day and still has a reason to buy the Panacea later.
--
-- Marked `support` so its cast previews green, and `restorative` so an Envenom charm sitting beside it
-- can't turn a curative into a poison.
return {
    name = "Clearwater Vial",
    description = "A draught of clean water. Removes every debuff from yourself.",
    sprite = "assets/items/clearwater_vial.png",
    type = "consumable",
    tags = { "potion", "restorative" },
    class = "alchemist",
    price = 35,
    repRank = 1,
    activeAbility = {
        target = "self",
        support = true,
        range = 0,
        speed = 2,
        consumesItem = true,
        effect = function(fx)
            fx.cleanse(fx.user)
        end,
    },
}
