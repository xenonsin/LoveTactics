-- Hollowed: the body goes thin. Steel barely finds it -- and everything else finds it far too easily.
--
-- Built out of two numbers that already existed, pointed in opposite directions: an enormous
-- `statBonus.defense` (folded through Combat.flatStat, so it subtracts from every physical blow exactly
-- as armor does) against a real `vulnerable.magical`. A sword swing lands for the floor of 1; a fire
-- bolt lands for rather more than it would have.
--
-- The defense is a big number rather than an immunity flag ON PURPOSE. Damage in this game floors at 1
-- and never at 0, and that floor is load-bearing: a scratch is still a hit, so it still provokes
-- counters, still feeds Rimebitten, still wakes a sleeper, still advances a boss phase. A true physical
-- immunity would quietly switch all of that off and would need every one of those rules to learn a new
-- case. This needs none of them to change and reads, at the table, as "steel does nothing" -- which is
-- what the player actually wanted to buy.
--
-- The trade is the item. A knight who goes hollow to walk out of a melee has made themself the softest
-- thing on the board to the enemy mage, and the enemy mage gets a turn.
return {
    name = "Hollowed",
    abbr = "Holw",
    description = "Hollowed: physical blows barely land, and magic bites far deeper.",
    color = { 0.78, 0.80, 0.86 }, -- badge tint (thin grey-white)
    duration = 10,                -- ~2 turns: an escape, not a stance
    statBonus = { defense = 40 }, -- steel finds the floor of 1 and nothing more
    vulnerable = { magical = 10 },
}
