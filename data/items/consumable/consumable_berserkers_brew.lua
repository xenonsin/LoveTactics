-- Berserker's Brew: the alchemist half of the Warbrewer (fighter x alchemist). Quaffed, it hands the
-- turn straight back (fx.grantExtraAction -- an extra action this turn) and leaves the drinker Reckless
-- (data/status/status_reckless.lua -- it takes more damage while it lasts). Wrath bought out of a vat:
-- the rampage is real, and so is the wide-open guard that pays for it. Consumed on use.
return {
    name = "Berserker's Brew",
    description = "Grants an extra action now, but leaves you Reckless: you take more damage for a time.",
    flavor = "The Crucible does not sell courage. It sells the part of you that forgets to be careful.",
    sprite = "assets/items/consumable_berserkers_brew.png",
    type = "consumable",
    tags = { "restorative" },
    class = "alchemist",
    discipline = "warbrewer", -- fighter x alchemist; the Combat-draught mechanic's first stock
    price = 120,
    repRank = 2,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 1, -- fast: the point is to keep swinging
        consumesItem = true,
        effect = function(fx)
            fx.applyStatus(fx.user, "status_reckless", { duration = 16 + 2 * fx.level })
            fx.grantExtraAction(1)
        end,
    },
}
