-- UNCOMMON. The one relic on this rung with no price attached, and it stays that way because it was
-- approved as written before the rung's rule was settled -- worth stating plainly rather than quietly
-- retro-fitting a cost onto something already agreed.
--
-- Pride's mechanic, found rather than bought: damage per ally standing beside you, read live off the
-- board every turn (trait_close_ranks, already written). The offensive twin of The Standing Order, and a
-- company holding both has decided to fight as a block.
return {
    name = "Rank and File",
    blurb = "+%d damage for each ally standing beside you.",
    tier = "uncommon", mark = "Rf",
    scale = { 1, 1 },
    traits = { "trait_close_ranks" },
    scope = "party",
}
