-- HEADS: how many mouths the Lernaean Hydra has right now (data/traits/trait_two_for_one.lua, models/lerna.lua).
-- Reviewed 2026-10-09 ("The Crown's Bestiary", slice E).
--
-- A COUNT, NOT A CLOCK: the pips are the readout, and the jaws read the same number (Lerna.strikes), so what the
-- badge says is how many times it bites. Three at the bell, six at most, never fewer than one. Not a debuff and
-- never stripped: a Dispel that took the heads would be a kill with a longer name.
return {
    name = "Heads",
    abbr = "Head",
    description = "Heads: bites once per head each turn.",
    color = { 0.300, 0.520, 0.420 }, -- badge tint (the marsh-green of the beast)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    magnitude = 3,
    stacks = 6,
}
