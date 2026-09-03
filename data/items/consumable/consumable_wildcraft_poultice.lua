-- Wildcraft Poultice: crushed leaf and root, pressed to the wound. The Herbalist (hunter x alchemist)
-- brews from what the field grows rather than what the vat distils: it restores health AND draws out
-- poison (data/status/status_poison.lua), the nature-remedy half of envy's craft. Consumed on use.
--
-- Home shelf is the Lodge (`class = "hunter"`), so it tallies toward the hunter and appears on the Lodge
-- and Crucible shelves both once Herbalist is unlocked. Deliberately NOT tagged `potion`: the Cafe
-- resells potions, and this is a discipline-locked field remedy, not a counter good.
local Curve = require("models.curve")

return {
    name = "Wildcraft Poultice",
    description = "Restores health to an ally and draws out Poison.",
    flavor = "The Crucible boils its cures. The Lodge already knew which leaf to crush.",
    sprite = "assets/items/consumable_wildcraft_poultice.png",
    type = "consumable",
    tags = { "restorative" },
    class = "herbalist", -- hunter x alchemist; the Field-brewing mechanic's first stock
    price = 230,
    unlockQuests = 6,
    activeAbility = {
        target = "ally", -- includes the user (a unit is its own ally)
        range = 1,
        speed = 2,
        consumesItem = true,
        healing = Curve.ramp(20),
        ai = { priority = "emergency", act = "support", targetPref = "lowest_hp",
               when = { subject = "self", test = "hp_pct_below", value = 0.35 } },
        effect = function(fx)
            fx.heal(fx.target, fx.amount)
            fx.clearStatus(fx.target, "status_poison")
        end,
    },
}
