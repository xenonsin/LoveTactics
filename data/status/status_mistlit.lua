-- Mistlit: the Nymph's light, and the one piece of her kit that is about somebody else's turn.
--
-- TWO THINGS, AND THEY ARE ONE IDEA. The body is lit up so plainly that concealment does not answer for
-- it (`revealsBearer`, the flag Limned reads -- Status.limned), and the next shove that finds it throws
-- it one tile further than the shove was meant to (`shoveBonus`, read by Combat.knockback, which spends
-- this status on that shove). A marker, in other words, for whoever does the throwing.
--
-- WHICH IS WHY A NYMPH IS A NUISANCE ON HER OWN AND A PROBLEM BESIDE A HARPY. A gust that moves a body a
-- tile moves a lit one two, and Combat.knockback bills the impact of every tile a shove could not spend
-- -- so on a board with a hedge behind you, the extra tile is usually the one that hurts.
--
-- A plain shove only. A THROWN body picked its own landing, and a pull brings a body to the puller's
-- side however far that is; neither has a spare tile for the light to add.
return {
    name = "Mistlit",
    abbr = "Mst",
    description = "Lit up: cannot hide, and the next shove throws it one tile further.",
    color = { 0.690, 0.831, 0.878 }, -- badge tint (mist)
    duration = 18,                -- about three turns: long enough for the flock to find it
    debuff = true,                -- Cure lifts it
    revealsBearer = true,         -- Status.limned: targetable however well it hides
    shoveBonus = 1,               -- Status.shoveBonus: tiles added to the next knockback
}
