-- UNCOMMON. The caster's Quick Draw, and the relic that gives The Overfull Flask a reason to exist: a
-- common that raises the mana ceiling is doing very little on its own, and a great deal beside a trade
-- that makes every cast cost more.
--
-- The mana half is a RULE for the same reason The Quick Draw's stamina half is.
return {
    name = "The Overreach",
    blurb = "+%d magic damage for the whole company.",
    tier = "uncommon", mark = "Or",
    cost = "+%d mana on every cast.",
    costScale = { 3, 1 },
    scale = { 3, 2 },
    bonus = { magicDamage = 3 },
    bonusStep = { magicDamage = 2 },
    rules = { manaSurcharge = true },
    ruleScale = { manaSurcharge = { 3, 1 } },
}
