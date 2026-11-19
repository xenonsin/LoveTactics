-- Sanguine Font: the barbarian's Blood Price multiplier (docs/engines.md). Health lost on your own turn
-- banks Blood, up to four, and the next ability spends all of it for 3 more damage a point
-- (trait_sanguine_font). The Red Tithe and the Wound Gift are what feed it on purpose; a riposte taken
-- mid-swing feeds it by accident.
--
-- Reworked from The Keen Edge (2026-11-18), a +3/-3 stat trade whose relic twin (relic_keen_edge)
-- still carries that trade for the company. The id stays so saves and drop lists keep their piece.
return {
    name = "Sanguine Font",
    description = "Each time you lose health on your turn, your next ability deals 3 more (up to 12).",
    flavor = "The Colosseum's barbarians do not bandage between bouts. They say it keeps the arm honest.",
    sprite = "assets/items/keen_edge.png",
    type = "utility",
    tags = { "trinket" },
    class = "barbarian",
    grade = 0.90,
    unlockLevel = 12,
    charge = { key = "blood", from = { "selfWound" }, max = 4 },
    traits = { "trait_sanguine_font" },
    bonus = { damage = 1 },
}
