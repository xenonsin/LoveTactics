-- Resistant: Lightning -- a protective working laid on the caster or a nearby ally, granting
-- Resistant: Lightning (data/status/status_resistant_lightning.lua): -4 to every lightning-tagged
-- hit for a time. It floors at 1 and never reaches immunity -- that is Immunity: Lightning, the
-- same house's deeper answer. The ACTIVE mirror of the Vulnerable openers: read the intent
-- telegraph and ward the target of the incoming blow the turn before it lands.
--
-- A HOUSE WARDS AGAINST WHAT IT DEALS, which is the rule this line follows now. The storm is the
-- Arcanum's own, and pride is what tells it no. The 22 wards and seals used to sit on two racks --
-- eleven on the priest's shelf and eleven on the mage's, a third of each shelf's ability list
-- saying one thing eleven times over. Split by damage type, every house teaches the answer to the
-- damage it knows best. See docs/vulnerability.md.
return {
    name = "Resistant: Lightning",
    description = "Wards yourself or an ally with Resistant: Lightning.",
    flavor = "The bolt still comes. It simply forgets, halfway, why it was so angry.",
    sprite = "assets/items/ability_ward_lightning.png",
    type = "ability",
    tags = { "protective" },
    class = "mage",
    price = 165,
    unlockQuests = 1,
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
