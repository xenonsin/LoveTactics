-- Defense Up, S -- and the reason it is worth a line of its own beside the Macchiato is that
-- mitigation in this game is SUBTRACTIVE (docs/balance.md): a point of defense and a point of weapon
-- power are the same quantity, taken off opposite ends of the same exchange. So this is not the timid
-- order. Against a field of many small blows it is strictly the better one, and against one enormous
-- blow it is strictly the worse -- which is the read the player is buying at the counter.
--
-- Split across both defenses rather than stacked on one, because a company is mixed and a supper does
-- not know what is going to be thrown at it. The physical side is the larger half: most of what a
-- campaign throws is still steel.
return {
    name = "Soup in a Crust",
    description = "The whole company takes less from blows and from spells for the quest.",
    flavor = "A loaf hollowed out and filled at the last moment, so that the bowl is the best part of it.",
    price = 60,
    unlockPrestige = 1,
    bonus = { defense = 2, magicDefense = 1 },
}
