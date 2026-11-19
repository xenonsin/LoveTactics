-- Hollow Idol: the Monk's grid joker (docs/engines.md). Every ability the bearer casts deals 2 more for
-- each empty cell in its grid (trait_hollow_idol). The lean-build payoff, on the class that already
-- fights with nothing in its hands.
--
-- Reworked from The Overreach (2026-11-18), a +3 magic damage / +3 mana trade whose relic twin still
-- carries that trade for the company. Moved from the elementalist shelf to the monk's. The id stays.
return {
    name = "Hollow Idol",
    description = "Your abilities deal 2 more for each empty grid slot.",
    flavor = "Carved hollow on purpose. The Lodge says the empty part is the idol.",
    sprite = "assets/items/overreach.png",
    type = "utility",
    tags = { "charm" },
    class = "monk",
    grade = 0.90,
    unlockLevel = 12,
    traits = { "trait_hollow_idol" },
    bonus = { speed = 1 },
}
