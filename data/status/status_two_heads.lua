-- TWO HEADS: the strikes the Two Heads coat has banked (data/traits/trait_two_heads.lua, models/lerna.lua).
-- Reviewed 2026-10-09 ("The Crown's Bestiary", slice E). Each slash blow that strikes the wearer adds one; the
-- next weapon attack lands once more per stack and spends them all.
--
-- A COUNT, NOT A CLOCK, read by the swing itself (Lerna.strikes), so the hover quotes the extra landings too.
return {
    name = "Two Heads",
    abbr = "2Hd",
    description = "Two Heads: the next weapon attack strikes one more time for each stack.",
    color = { 0.300, 0.520, 0.420 },
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 3,
}
