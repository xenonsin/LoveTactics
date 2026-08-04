-- Resistant: Fire -- a protective working laid on the caster or a nearby ally, granting Resistant:
-- Fire (data/status/status_resistant_fire.lua): -8 to every fire-tagged hit for a time. It floors
-- at 1 and never reaches immunity -- that is Immunity: Fire, the same house's deeper answer. The
-- ACTIVE mirror of the Vulnerable openers: read the intent telegraph and ward the target of the
-- incoming blow the turn before it lands.
--
-- A HOUSE WARDS AGAINST WHAT IT DEALS, which is the rule this line follows now. The pit has watched
-- enough men go up to know exactly how it is survived. The 22 wards and seals used to sit on two
-- racks -- eleven on the priest's shelf and eleven on the mage's, a third of each shelf's ability
-- list saying one thing eleven times over. Split by damage type, every house teaches the answer to
-- the damage it knows best. See docs/vulnerability.md.
return {
    name = "Resistant: Fire",
    description = "Wards yourself or an ally with Resistant: Fire.",
    flavor = "The pit cannot stop the fire being thrown. It can decide it lands soft.",
    sprite = "assets/items/ability_ward_fire.png",
    type = "ability",
    tags = { "protective" },
    class = "fighter",
    price = 180,
    unlockQuests = 3,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 3,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_resistant_fire")
        end,
    },
}
