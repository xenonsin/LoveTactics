-- Ward: Lightning -- a priest's protective blessing laid on the caster or a nearby ally, granting Resistant: Lightning
-- (data/status/status_resistant_lightning.lua): -8 to every lightning-tagged hit for a time. Warding is the Cathedral's
-- own keyword (docs/classes.md), single-element rather than the Magical Barrier's single-school. The
-- ACTIVE mirror of the Vulnerable openers -- read the intent telegraph, ward the target of the incoming
-- blow the turn before it lands. It floors at 1 and never reaches immunity (that is the mage's Immunity: Lightning).
-- One of the ward line; see docs/vulnerability.md.
return {
    name = "Ward: Lightning",
    description = "Wards yourself or an ally with Resistant: Lightning.",
    flavor = "The bolt still comes. It simply forgets, halfway, why it was so angry.",
    sprite = "assets/items/ability_ward_lightning.png",
    type = "ability",
    tags = { "protective", "holy" },
    class = "priest",
    price = 180,
    repRank = 2,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 3,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_resistant_lightning")
        end,
    },
}
