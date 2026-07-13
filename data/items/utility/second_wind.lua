-- Second Wind: one refusal to fall. A passive charm that grants the Second Wind trait
-- (data/traits/second_wind.lua): the first blow that would drop the bearer instead stands it back up
-- at half its maximum health -- once per battle (Combat.dealFlatDamage consults Trait.trySurvive at the
-- death threshold). Insurance against the one hit you did not see coming; spent, it waits for the next
-- fight to reset.
return {
    name = "Second Wind",
    description = "Once per battle, survive a killing blow and rise at half health.",
    sprite = "assets/items/second_wind.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    price = 360,
    repRank = 3,
    traits = { "second_wind" },
}
