-- SPILLED PURSE: one of the Gold Golem's three trophies (round 2, "The Golems of Greed"). The Hoard Falls
-- Out, on the company's side: a foe the wearer kills leaves a coin heap where it fell (trait_spilled_purse).
-- It makes heaps on every floor, so Heart of Gold, Gilt Plating and Veinfinder work together anywhere.
-- Gold off a kill, never a piece -- the no-kill-to-take rule outside Gula is about gear.
return {
    name = "Spilled Purse",
    description = "A foe you kill leaves a coin heap where it fell.",
    flavor = "Everyone is carrying something. This makes sure it ends up on the floor.",
    sprite = "assets/items/utility_spilled_purse.png",
    type = "utility",
    tags = { "trinket" },
    class = "mammonite",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_spilled_purse" },
}
