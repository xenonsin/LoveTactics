-- AMBITION: the Tower-Giant's count, and the Babel Maul's (data/traits/trait_ambition.lua; "Pride's Bestiary",
-- 2026-09-30). One stack at the end of each of the bearer's turns, never lost on its own, and consumed all at
-- once: the Giant's by its fall (trait_the_proud_fall, which crashes wider and harder the more it holds), the
-- Maul's by its next hit (+3 damage a stack). One word for one mechanic -- the count -- with two payoffs.
--
-- Not a debuff, and it carries no stat of its own: what it is worth is the item that consumes it.
return {
    name = "Ambition",
    abbr = "Amb",
    description = "Ambition: grows by one each turn, and is consumed all at once.",
    color = { 0.820, 0.700, 0.360 }, -- badge tint (gilt stone)
    duration = math.huge,
    hideDuration = true,
    hideLog = true, -- it grows every turn; the badge's count is the read, not a line a turn
    magnitude = 1,
    stacks = 99,
}
