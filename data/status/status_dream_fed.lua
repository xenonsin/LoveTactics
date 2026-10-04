-- DREAM-FED: Baku's meal (data/traits/trait_dream_eating.lua; "Sloth's Bestiary", 2026-10-04). One stack for each
-- Asleep or Dormant body within 3 of it when its turn opened, +2 Damage a stack.
--
-- READ FRESH EVERY TURN, NOT BANKED (models/sloth_dreamers.lua's feed): the badge is set to the count, so a company
-- that wakes its sleepers starves it on its very next turn rather than only stopping it growing. The heal is the
-- half that keeps. Lasts until that next turn re-reads it; a strip takes it early.
return {
    name = "Dream-Fed",
    abbr = "Fed",
    description = "Dream-Fed: more damage for each sleeper it fed on this turn.",
    color = { 0.560, 0.420, 0.720 }, -- badge tint (a dream's violet)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 8,
    statBonus = { damage = 2 },
    statBonusScales = true,
}
