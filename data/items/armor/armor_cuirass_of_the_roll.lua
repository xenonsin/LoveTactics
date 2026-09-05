-- Bastion rank-2. Opens each battle with bonus defense for every ally already standing beside the
-- wearer (trait_muster_roll).
--
-- Formation priced at SETUP rather than per-turn, which is a different item from everything else on
-- this shelf. An Oathkeeper spreads its brace when you spend the turn to plant it; a Shared Bulwark
-- holds ground for as long as the line stays behind it. This is settled once, at the bell, off the
-- deployment the player chose before the fight started -- and then it is simply true for the rest of
-- the battle whether the line holds or not.
--
-- So what it actually sells is a reward for the one decision this game asks for and rarely pays out
-- on: where everybody stands before anybody has moved. A knight deployed in the corner gets nothing.
--
-- The knight's cheapest real chestpiece, and the entry rung between chainmail's flat steel and the
-- Warden's Oath at rank 3. utility_greywatch_muster_roll grants the same rule from a cell -- and
-- because both read the same opening tally, wearing both genuinely stacks, which is the intended
-- expensive build rather than an oversight.
local Curve = require("models.curve")

return {
    name = "Cuirass of the Roll",
    description = "Increase defense at battle start for each adjacent ally.",
    flavor = "The Bastion reads the roll before the gate opens. Answering to your own name is the smallest part of it.",
    sprite = "assets/items/armor_cuirass_of_the_roll.png",
    type = "armor",
    tags = { "plate" },
    class = "knight",
    unlockQuests = 5,
    dropTier = 6,
    traits = { "trait_muster_roll" },
    bonus = { defense = Curve.ramp(6, 16), movement = -1 },
    resist = { physical = 2 },
}
