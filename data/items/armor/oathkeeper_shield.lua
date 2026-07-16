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
    bonus = { defense = { 9, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18 }, movement = -1 },
    resist = { physical = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 }, slash = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 }, pierce = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 }, impact = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } },
    -- A tower shield braces hardest of all -- a large, forge-scaling +defense while it holds the line.
    -- `covers` is its EXTRA over the plain buckler (data/items/armor/buckler.lua), which swaps Wait for
    -- the same Defend: this one does not brace alone. Every ADJACENT ALLY braces with it, for about
    -- half as much, which turns the Bastion's dullest verb into the most positional one on the board --
    -- where you plant decides who else gets the wall, and a line of three behind one Oathkeeper is
    -- worth more than three bucklers scattered. The oath is not that you survive; it is that they do.
    waitBehavior = {
        kind = "defend", speed = 4,
        defense = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
        covers = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 },
    },
}
