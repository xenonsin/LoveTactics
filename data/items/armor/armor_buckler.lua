-- A shield: a small passive defense bonus, and it swaps the holder's Wait action into Defend --
-- end the turn to raise physical defense (the Defending status) until this unit's next turn.
-- See Combat.waitBehavior / Combat.defend and data/status/defending.lua.
return {
    name = "Buckler",
    description = "Replaces Wait with Defend: brace for a burst of physical defense.",
    flavor = "The Bastion issues one to every recruit, before it issues them an opinion.",
    sprite = "assets/items/buckler.png",
    type = "armor",
    tags = { "shield" }, -- a Shield Bash item beside it in the grid can bash with it
    class = "knight",
    price = 220,
    repRank = 2,
    bonus = { defense = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
    resist = { physical = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
    -- Defend brace: the temporary +defense while braced, tuned here and climbing with the forge.
    waitBehavior = { kind = "defend", speed = 5, defense = { 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11 } },
}
