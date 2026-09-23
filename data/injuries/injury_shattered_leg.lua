-- SHATTERED LEG: the one injury that changes the BOARD rather than the numbers on it.
--
-- Two spaces off the body's movement, for as long as it holds. It hits as hard as it ever did and takes
-- a blow as well as it ever did -- it simply arrives a turn later, everywhere, for the rest of the
-- campaign, which on a tactics board is a different kind of loss from a smaller number.
--
-- THE MAGNITUDE IS CRIPPLE'S OWN (data/status/status_cripple.lua), because the board has already been
-- balanced against exactly this much missing movement and there is no reason to invent a second figure
-- for the same disability. What it does NOT do is reuse Cripple's blueprint -- see
-- data/status/status_shattered_leg.lua for why an injury may never wear a cleansable badge.
return {
    name = "Shattered Leg",
    description = "Shattered Leg: moves fewer spaces each turn.",
    severity = 2,
    weight = 15,
    reserve = { health = 0.06 },
    effects = { { id = "status_shattered_leg" } },
}
