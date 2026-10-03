-- RED STONE: the lives a Homunculus holds in its heart (data/traits/trait_red_stone.lua), and the store the Stone
-- Heart banks off each kill (data/traits/trait_stone_heart.lua). "Envy's Bestiary", 2026-10-03, slice C.
--
-- A COUNT, NOT A CLOCK: the pips are the whole readout. A killing blow consumes one instead of landing
-- (Trait.trySurvive -> models/envy_seat.lua); what happens after is the carrier's rule, not this badge's. Named
-- Red Stone and not Stone, which is Medusa's petrify count -- one word per mechanic.
--
-- Not a debuff, and never stripped: a Dispel that took a Homunculus's lives would be a kill with a longer name.
return {
    name = "Red Stone",
    abbr = "RStn",
    description = "Red Stone: a killing blow consumes one instead.",
    color = { 0.780, 0.160, 0.200 }, -- badge tint (the stone's own red)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    magnitude = 1,
    stacks = 3,
}
