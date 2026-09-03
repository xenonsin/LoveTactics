-- RARE. Abilities cost no mana; every cast takes that much health instead. One currency swapped for
-- another, and the consequence is that the caster becomes the body that must be protected -- which
-- changes the value of every heal and every ward on the shelf at a stroke.
--
-- THE RULE FIRES ONCE; the magnitude is RELIEF rather than power. The swap is total at one copy, so a
-- second makes it cheaper: the health charged falls from 100% of the mana price to 75%, then 50%. The
-- one rare whose deepening makes you safer instead of stronger, which the rung needs at least one of.
return {
    name = "The Overdraft",
    blurb = "Abilities cost no mana. Each cast takes %d%% of that price in health.",
    tier = "rare", mark = "Od",
    cost = "Health for every spell.",
    scale = { 100, -25 },
    rules = { manaToHealth = true },
    ruleScale = { manaToHealth = { 1.0, -0.25 } }, -- fraction of the mana price paid as health
}
