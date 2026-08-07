-- Resistant: Slash -- a protective working laid on the caster or a nearby ally, granting Resistant:
-- Slash (data/status/status_resistant_slash.lua): -8 to every slash-tagged hit for a time. It
-- floors at 1 and never reaches immunity -- that is Immunity: Slash, the same house's deeper
-- answer. The ACTIVE mirror of the Vulnerable openers: read the intent telegraph and ward the
-- target of the incoming blow the turn before it lands.
--
-- A HOUSE WARDS AGAINST WHAT IT DEALS, which is the rule this line follows now. Turning an edge is
-- the Bastion's entire trade, and this is that plate said as a working. The 22 wards and seals used
-- to sit on two racks -- eleven on the priest's shelf and eleven on the mage's, a third of each
-- shelf's ability list saying one thing eleven times over. Split by damage type, every house
-- teaches the answer to the damage it knows best. See docs/vulnerability.md.
return {
    name = "Resistant: Slash",
    description = "Wards yourself or an ally with Resistant: Slash.",
    flavor = "The edge arrives sure of itself. The plate is what makes it wrong.",
    sprite = "assets/items/ability_ward_slash.png",
    type = "ability",
    tags = { "protective" },
    class = "knight",
    price = 140,
    unlockQuests = 1,
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
