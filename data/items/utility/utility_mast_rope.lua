-- THE MAST-ROPE: one of the Siren's own (data/characters/character_siren.lua). Odysseus lashed to the
-- mast, with the whole crew on the rope: while the bearer stands beside allies, neither it nor any ally
-- touching it can be shoved, pulled or thrown (trait_mast_rope, read in Status.blocksForcedMove). The
-- fen's HOLD piece, worn by the player -- keep your line together and the water cannot take anyone out
-- of it. It is honest in both directions: your own shoves cannot move them either.
--
-- Keno's note on review: "Have it lash with adjacent team" -- a passive over everyone touching you,
-- not once a battle over one body.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Mast-Rope",
    description = "You and every ally beside you cannot be shoved, pulled or thrown.",
    flavor = "Tied to the mast, he heard all of it. The knots were the crew's idea.",
    sprite = "assets/items/utility_mast_rope.png",
    type = "utility",
    tags = { "protective" },
    class = "priest",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_mast_rope" },
}
