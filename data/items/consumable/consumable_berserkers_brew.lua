-- Berserker's Brew: the alchemist half of the Warbrewer (fighter x alchemist). A FREE action to quaff
-- (ab.free -- the Battle Tonic pattern, drunk between doing things without spending the turn's action),
-- it grants an extra action (fx.grantExtraAction) and leaves the drinker Reckless (data/status/
-- status_reckless.lua -- it takes more damage while it lasts). Free is load-bearing, not flavor: an
-- ordinary active that only granted an extra action would have the closing endTurn spend that grant
-- immediately, netting zero. Free keeps the drinker's normal swing, so the granted one is a true second
-- blow. Wrath bought out of a vat: the rampage is real, and so is the wide-open guard that pays for it.
-- One quaff per turn (Combat.FREE_ACTIONS_PER_TURN). Consumed on use.
return {
    name = "Berserker's Brew",
    description = "Grants an extra action now, but leaves you Reckless.",
    flavor = "The Crucible does not sell courage. It sells the part of you that forgets to be careful.",
    sprite = "assets/items/consumable_berserkers_brew.png",
    type = "consumable",
    tags = { "restorative" },
    class = "alchemist",
    discipline = "warbrewer", -- fighter x alchemist; the Combat-draught mechanic's first stock
    price = 270,
    unlockQuests = 10,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 0, -- a free draught bills no tempo of its own (cf. consumable_battle_tonic)
        free = true, -- an EXTRA, not the turn's action: keep your swing, the grant is the second one
        consumesItem = true,
        effect = function(fx)
            fx.applyStatus(fx.user, "status_reckless", { duration = 16 + 2 * fx.level })
            fx.grantExtraAction(1)
        end,
    },
}
