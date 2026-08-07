-- Resistant: Dark -- a protective working laid on the caster or a nearby ally, granting Resistant:
-- Dark (data/status/status_resistant_dark.lua): -8 to every dark-tagged hit for a time. It floors
-- at 1 and never reaches immunity -- that is Immunity: Dark, the same house's deeper answer. The
-- ACTIVE mirror of the Vulnerable openers: read the intent telegraph and ward the target of the
-- incoming blow the turn before it lands.
--
-- A HOUSE WARDS AGAINST WHAT IT DEALS, which is the rule this line follows now. Nobody answers the
-- dark faster than the people who work in it. The 22 wards and seals used to sit on two racks --
-- eleven on the priest's shelf and eleven on the mage's, a third of each shelf's ability list
-- saying one thing eleven times over. Split by damage type, every house teaches the answer to the
-- damage it knows best. See docs/vulnerability.md.
return {
    name = "Resistant: Dark",
    description = "Wards yourself or an ally with Resistant: Dark.",
    flavor = "Everyone down here works by touch. The ward is only the touch made certain.",
    sprite = "assets/items/ability_ward_dark.png",
    type = "ability",
    tags = { "protective" },
    class = "rogue",
    price = 260,
    unlockQuests = 3,
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
