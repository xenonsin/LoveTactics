-- RARE. The company fights from one shared health pool, equal to the sum of their maxima. Nobody can be
-- focused down and nobody can be saved: the frail bodies are as durable as the knight and the knight is
-- as fragile as them, so the whole calculus of who stands where inverts.
--
-- Distinct from status_shared_burden, which pairs two bodies and halves a wound between them. This is
-- one bar for everyone, and when it empties the company falls together.
--
-- THE RULE FIRES ONCE; the magnitude is a surcharge on the pool. One pool is one pool, so a second copy
-- pays 15% over the sum for the risk already accepted -- the only relic on the shelf that makes the
-- company's total health exceed the sum of its parts, and the thing that keeps a duplicate from being a
-- dead draw.
--
-- Resolves between the Vow and the Breath (Relic.RULE_ORDER): the pool is formed from maxima already
-- adjusted, and can then still be pinned.
return {
    name = "The Yoked Company",
    blurb = "One shared health pool for the company, +%d%% over the sum of their maxima.",
    tier = "rare", mark = "Yc",
    cost = "When it empties, everyone falls at once.",
    scale = { 0, 15 },
    rules = { sharedPool = true },
    ruleScale = { sharedPool = { 0, 15 } }, -- percent over the summed maxima
}
