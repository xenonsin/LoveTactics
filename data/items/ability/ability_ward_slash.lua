-- Resistant: Slash -- a priest's protective blessing laid on the caster or a nearby ally, granting Resistant: Slash
-- (data/status/status_resistant_slash.lua): -8 to every slash-tagged hit for a time. Warding is the Cathedral's
-- own keyword (docs/classes.md), single-element rather than the Magical Barrier's single-school. The
-- ACTIVE mirror of the Vulnerable openers -- read the intent telegraph, ward the target of the incoming
-- blow the turn before it lands. It floors at 1 and never reaches immunity (that is the mage's Immunity: Slash).
-- One of the ward line; see docs/vulnerability.md.
return {
    name = "Resistant: Slash",
    description = "Wards yourself or an ally with Resistant: Slash.",
    flavor = "The edge arrives sure of itself. The blessing is what makes it wrong.",
    sprite = "assets/items/ability_ward_slash.png",
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
            fx.applyStatus(fx.target, "status_resistant_slash")
        end,
    },
}
