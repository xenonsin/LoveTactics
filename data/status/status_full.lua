-- FULL: a meal in the belly, counted. The Sated's resource and the word for it wherever a body carries one
-- (data/traits/trait_three_meals.lua). Reviewed 2026-09-23 ("The Sated and the Flight"): a meal is WEIGHT
-- -- it hits harder and armours better, and it cannot get about -- so emptying the belly is how the fight
-- comes apart, and eating is how it puts itself back together.
--
-- The table below is ONE meal (`statBonusScales`, Status.statBonus), and it is the Sated's. A player's
-- piece that fills its bearer hands in a table of its own at apply time (the Distended Girth, the
-- Bottomless Gut), which overrides this one outright -- the same override an injury uses -- so the badge
-- reads what is actually being carried.
--
-- NOT A DEBUFF, and no Cure empties a stomach: meals leave by being SPENT (Retch, Settle), knocked loose
-- (a critical on the Sated), or shed (the Girth). Battle-long, like Enraged.
return {
    name = "Full",
    abbr = "Ful",
    description = "Each meal: increase damage and defense, reduce movement and speed.",
    color = { 0.600, 0.520, 0.210 }, -- badge tint (tallow)
    duration = 999,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 3,
    statBonus = { damage = 3, defense = 3, movement = -1, speed = -1 },
    statBonusScales = true,
}
