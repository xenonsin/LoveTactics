-- The Skimmer's Cut: a set of shears, a lining hook and a very small blade, worn at the belt where a
-- second dagger would go. It carries the trait of the same name
-- (data/traits/trait_skimmers_cut.lua) -- Final Fantasy Tactics' Gilgame Heart and Steal Gil, which
-- turned a fight into an income.
--
-- It is the only item in the game that pays you for playing, and that is exactly why it is on greed's
-- shelf and priced where it is. Every other utility answers "how do I win this fight". This one
-- answers "what am I getting out of this", which is a different question and a worse one to be asking,
-- and the Undercroft asks it constantly.
--
-- THE COST IS THE SLOT, and the slot is the whole balance of the thing. It grants no damage, no
-- defense, no reach and no reflex; a rogue wearing this is measurably worse at fighting than a rogue
-- wearing anything else on the rack. What it buys back is that the fight pays for itself, and whether
-- that is a good trade depends entirely on whether you were going to win comfortably anyway -- which
-- makes it a difficulty knob the player sets voluntarily, and a genuinely interesting one. It is best
-- in the fights that need it least.
--
-- It pays out with the spoils on a WIN. A wipe takes the takings with it, so it never makes losing
-- worth farming (see Combat.skimGold for the seam and why it works that way).
--
-- The name is the Undercroft's own term of art, and it is not a metaphor -- a skimmer's cut is the
-- share the man who thins the coins keeps for himself.
return {
    name = "Skimmer's Cut",
    description = "Every blow you land on a living foe lifts a little coin, paid out with the spoils.",
    flavor = "The Undercroft's term of art, and not a metaphor: the share the man who thins the coins keeps.",
    sprite = "assets/items/skimmers_cut.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    price = 340,
    repRank = 2,
    traits = { "trait_skimmers_cut" },
}
