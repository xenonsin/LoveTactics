-- Endurance: a deeper well of wind. A passive charm that raises the bearer's maximum stamina
-- (`maxBonus.stamina`, folded into Combat.unreservedMax). Stamina refills to its full effective ceiling
-- at the start of each battle, so unlike Toughness this bigger pool is usable from the opening bell --
-- more strikes and abilities before you have to Focus or wait to recover.
return {
    name = "Endurance",
    description = "Raises your maximum stamina by 15.",
    sprite = "assets/items/endurance.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    price = 160,
    repRank = 2,
    maxBonus = { stamina = 15 },
}
