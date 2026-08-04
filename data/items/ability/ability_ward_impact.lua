-- Resistant: Impact -- a protective working laid on the caster or a nearby ally, granting
-- Resistant: Impact (data/status/status_resistant_impact.lua): -8 to every impact-tagged hit for a
-- time. It floors at 1 and never reaches immunity -- that is Immunity: Impact, the same house's
-- deeper answer. The ACTIVE mirror of the Vulnerable openers: read the intent telegraph and ward
-- the target of the incoming blow the turn before it lands.
--
-- A HOUSE WARDS AGAINST WHAT IT DEALS, which is the rule this line follows now. The Colosseum sells
-- the hammer, so it sells the answer to one. The 22 wards and seals used to sit on two racks --
-- eleven on the priest's shelf and eleven on the mage's, a third of each shelf's ability list
-- saying one thing eleven times over. Split by damage type, every house teaches the answer to the
-- damage it knows best. See docs/vulnerability.md.
return {
    name = "Resistant: Impact",
    description = "Wards yourself or an ally with Resistant: Impact.",
    flavor = "A blow lands where it means to. It simply means less.",
    sprite = "assets/items/ability_ward_impact.png",
    type = "ability",
    tags = { "protective" },
    class = "fighter",
    price = 180,
    unlockQuests = 2,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 3,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_resistant_impact")
        end,
    },
}
