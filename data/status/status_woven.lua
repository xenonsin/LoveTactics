-- WOVEN: Arachne's tapestry (data/traits/trait_the_tapestry.lua, models/envy_seat.lua). "Envy's Bestiary",
-- 2026-10-03, slice C. Every ability the company casts in her sight is a thread on it, kept per ability on this
-- instance (`threads`), and the badge counts the most threads any one of them has. At 3 she casts that one back.
--
-- The record and the readout are one table, as Already Known's is. Not a debuff, and never stripped: what she has
-- seen she has seen.
return {
    name = "Woven",
    abbr = "Wvn",
    description = "Woven: at 3 threads of one ability, it is cast back at whoever cast it.",
    color = { 0.820, 0.780, 0.640 }, -- badge tint (undyed thread)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    magnitude = 0,
}
