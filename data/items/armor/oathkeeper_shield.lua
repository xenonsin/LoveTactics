-- Bastion rank-4. Passive, and it swaps the bearer's Wait into Defend (like data/items/armor/
-- buckler.lua) -- the Bastion's whole doctrine in one item: the turn you do nothing is the turn
-- you hold the line.
--
-- Every Oathkeeper is inscribed with the name of a knight who set theirs down. The Bastion keeps
-- the list long and reads it aloud -- the first hint of Sloth, which is not idleness but the oath
-- abandoned.
return {
    name = "Oathkeeper Shield",
    description = "A tower shield bearing the names of the forsworn. Replaces Wait with Defend.",
    sprite = "assets/items/oathkeeper_shield.png",
    type = "armor",
    tags = { "shield" }, -- a Shield Bash item beside it in the grid can bash with it
    class = "knight",
    price = 800,
    repRank = 4,
    bonus = { defense = 9, movement = -1 },
    resist = { physical = 4, slash = 3, pierce = 3, impact = 3 },
    waitBehavior = { kind = "defend", speed = 4 },
}
