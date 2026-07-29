-- Resistant: Dark -- a priest's protective blessing laid on the caster or a nearby ally, granting Resistant: Dark
-- (data/status/status_resistant_dark.lua): -8 to every dark-tagged hit for a time. Warding is the Cathedral's
-- own keyword (docs/classes.md), single-element rather than the Magical Barrier's single-school. The
-- ACTIVE mirror of the Vulnerable openers -- read the intent telegraph, ward the target of the incoming
-- blow the turn before it lands. It floors at 1 and never reaches immunity (that is the mage's Immunity: Dark).
-- One of the ward line; see docs/vulnerability.md.
return {
    name = "Resistant: Dark",
    description = "Wards yourself or an ally with Resistant: Dark.",
    flavor = "There are older nights than this one, and the Cathedral has knelt through them all.",
    sprite = "assets/items/ability_ward_dark.png",
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
            fx.applyStatus(fx.target, "status_resistant_dark")
        end,
    },
}
