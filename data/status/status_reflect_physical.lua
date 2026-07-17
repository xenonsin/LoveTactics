-- Reflect Steel: the physical twin of data/status/reflect_magic.lua. For a window, single-target
-- physical blows aimed at the bearer are turned around and land on whoever threw them -- a swing at
-- full weight, mitigated by the attacker's own armor coming back in.
--
-- Shorter than the magical mirror by a third, and deliberately so. The two schools are NOT symmetric in
-- how often they arrive: nearly every physical attack in the game is single-target (a sword, a bite, an
-- arrow), while a mage's heavy hitters are areas that pass through a mirror untouched. So the same
-- duration on both would make this one roughly twice the ward its twin is -- an eight-tick steel mirror
-- would simply switch off the melee half of an enemy team. Six is the price of catching the commoner
-- school.
--
-- The counterplay is the same shape and just as legible: hit it with an area, hit it with a spell, or
-- wait. Note the two mirrors compose -- a bearer wearing both answers everything single-target -- which
-- is a genuine build and a genuine cost: two casts, two windows, and both clocks running at once.
return {
    name = "Reflect Steel",
    abbr = "RefS",
    description = "Mirrored: single-target physical blows rebound onto the attacker.",
    color = { 0.85, 0.88, 0.95 }, -- badge tint (mirror-bright steel)
    duration = 10, -- ~2 turns at Status.TICKS_PER_TURN: shorter than the arcane mirror, as before,
                   -- but long enough that a melee attacker actually has to decide something
    reflects = "physical",
}
