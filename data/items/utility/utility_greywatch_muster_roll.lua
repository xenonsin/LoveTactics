-- Quest reward, slot 5 of the Bastion's line (data/quests/greywatch.lua). The garrison roll, still
-- nailed up in the ruin -- and beside it the tally Acedia scratched into the gatepost, which Rowan
-- reads as a count of days that relief did not come. It is not.
--
-- `class = "knight"` with NO `price`: unbuyable, and still tallying toward knight growth when it is
-- carried and used (docs/classes.md, "class without price"). That is the mechanism for a quest-only
-- item, and it beats inventing a flag.
--
-- The rule is in `traits` (data/traits/trait_muster_roll.lua): it pays for standing beside people,
-- which is the answer to the oath that bites you for not. A passive -- there is nothing to activate,
-- because the decision it prices was made before the first initiative was rolled.
return {
    name = "Greywatch Muster Roll",
    description = "Opens each battle with bonus defense for every ally already standing beside you.",
    flavor = "Forty-one names, and the order read them out for fifteen years as though it knew what " ..
        "the number counted.",
    sprite = "assets/items/greywatch_muster_roll.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    traits = { "trait_muster_roll" },
}
