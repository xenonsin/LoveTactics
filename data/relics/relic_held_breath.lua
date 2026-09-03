-- RARE. The rung's exemplar: an INVERSION, both halves felt from the first turn.
--
-- Health is pinned at 1 -- not maximum health, the CURRENT pool -- and in exchange both armours climb
-- with every point of the ceiling the body is now missing. Because mitigation here is subtractive that
-- is enormous: a knight at 68 maximum carries roughly +16 to each at one copy, which resolves most of
-- the bestiary to nothing, and dies instantly to the one blow that exceeds it. The company plays as
-- glass walls and the counter-play is anything that hits hard once.
--
-- THE RULE FIRES ONCE, THE MAGNITUDE LADDERS. You cannot be pinned twice, so a second copy improves the
-- rate of exchange instead: 1 armour per 4 missing health becomes 1 per 2, then 1 per 1. Authored as the
-- rate itself so the ladder is a single number.
--
-- Resolves LAST among the three rares that reach for the health pool (Relic.RULE_ORDER), because it is
-- the one whose text would read as broken if it silently lost to another.
return {
    name = "The Held Breath",
    -- STATED PER FOUR MISSING HEALTH, which is the one framing that makes this ladder a whole number.
    -- The underlying rate is 0.25 armour per point missing and it DOUBLES per copy (0.25 / 0.5 / 0.75),
    -- so a blurb phrased the other way round -- "1 armour per N missing" -- would have to read 4, then
    -- 2, then 1.33. Per four, the same ladder is 1, 2, 3.
    blurb = "Health pinned at 1. +%d to both armours for every 4 health missing.",
    tier = "rare", mark = "Hb",
    scale = { 1, 1 },
    cost = "Any blow that gets through kills.",
    rules = { pinHealth = true },
    -- Armour gained per point of maximum health missing. 0.25 is one per four; a second copy doubles it.
    ruleScale = { pinHealth = { 0.25, 0.25 } },
}
