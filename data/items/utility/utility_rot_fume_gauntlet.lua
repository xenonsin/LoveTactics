-- Rot-Fume Gauntlet: the knight half of the Plague Knight (knight x alchemist). Your blows land harder
-- for every poisoned body on the field.
--
-- This is rule R5, and it is what makes the discipline exist. Contagion spreads poison and poison ticks;
-- before this shipped, that was the whole loop, and the Plague Knight was manufacturing a status almost
-- nothing in the catalog read. A mechanic whose output nobody consumes only looks like a mechanic.
--
-- Counted across the WHOLE FIELD rather than on the target, and the difference matters. A bonus keyed to
-- "is the one I am hitting poisoned" would reward poisoning your victim first -- which is worse than
-- simply hitting it twice, and would have made the spread pointless. Counting everyone rewards the
-- spread itself: this gauntlet is a readout of how badly the fight is going for everybody else.
--
-- Pairs with the Plaguebearer's Draught in a way worth saying out loud: your own poisoned body counts.
-- A plague knight standing sick in the middle of a sick line is hitting harder for its own affliction,
-- which is the most honest sentence this discipline has.
return {
    name = "Rot-Fume Gauntlet",
    description = "Your blows land harder for every poisoned body on the field -- your own included.",
    flavor = "The smell arrives first. By the time it is unbearable, the arithmetic has already happened.",
    sprite = "assets/items/utility_rot_fume_gauntlet.png",
    type = "utility",
    tags = { "charm", "poison" },
    class = "knight",
    discipline = "plague_knight",
    price = 440,
    repRank = 4,
    traits = { "trait_rot_fume" },
}
