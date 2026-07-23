-- Greed's debuff-count scaling (docs/classes.md), sold as a charm. It grants the Cutpurse's Tally trait
-- (data/traits/trait_cutpurse_tally.lua): every blow the bearer lands bites harder for each debuff
-- already on the target. It is the standing-rule reading of Exploit Weakness -- the ability punishes an
-- opening once, this makes the whole kit punish openings all fight -- which is why greed's shelf wanted
-- the multiplier as a grid piece and not only as an action.
--
-- No stats of its own: the cost is the slot, the whole balance of the family (see the Skimmer's Cut and
-- the Deadhand Grip). It does nothing at all against an un-afflicted foe -- carrying it is a bet that
-- your party sets the table, which is the read the Undercroft rewards.
return {
    name = "Cutpurse's Tally",
    description = "Your blows deal extra damage for every debuff already on the target.",
    flavor = "The Undercroft keeps a running count of what a man is worth. So does this.",
    sprite = "assets/items/cutpurse_tally.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    price = 320,
    repRank = 3,
    traits = { "trait_cutpurse_tally" },
}
