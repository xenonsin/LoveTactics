-- A shield: a small passive defense bonus, and it swaps the holder's Wait action into Defend --
-- end the turn to raise physical defense (the Defending status) until this unit's next turn.
-- See Combat.waitBehavior / Combat.defend and data/status/defending.lua.
return {
    name = "Buckler",
    description = "A light shield. Replaces Wait with Defend: brace for a burst of physical defense.",
    sprite = "assets/items/buckler.png",
    type = "armor",
    class = "knight",
    price = 220,
    repRank = 2,
    bonus = { defense = 3 },
    resist = { physical = 1 },
    waitBehavior = { kind = "defend", speed = 5 },
}
