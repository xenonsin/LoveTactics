-- Resistant: Water -- a protective working laid on the caster or a nearby ally, granting Resistant:
-- Water (data/status/status_resistant_water.lua): -4 to every water-tagged hit for a time. It
-- floors at 1 and never reaches immunity -- that is Immunity: Water, the same house's deeper
-- answer. The ACTIVE mirror of the Vulnerable openers: read the intent telegraph and ward the
-- target of the incoming blow the turn before it lands.
--
-- A HOUSE WARDS AGAINST WHAT IT DEALS, which is the rule this line follows now. Gluttony's country
-- is wet -- the crossing, the river, the drowned ground. The 22 wards and seals used to sit on two
-- racks -- eleven on the priest's shelf and eleven on the mage's, a third of each shelf's ability
-- list saying one thing eleven times over. Split by damage type, every house teaches the answer to
-- the damage it knows best. See docs/vulnerability.md.
return {
    name = "Resistant: Water",
    description = "Wards yourself or an ally with Resistant: Water.",
    flavor = "The wave breaks. The warded one does not.",
    sprite = "assets/items/ability_ward_water.png",
    type = "ability",
    tags = { "protective" },
    class = "hunter",
    price = 260,
    unlockQuests = 3,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 3,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_resistant_water")
        end,
    },
}
