-- A shield, so it swaps Wait into Defend (docs/weapons.md). Its extra is that bracing NAILS YOU DOWN:
-- planting it also roots the holder (status_root), who cannot move until it lifts -- in exchange for the
-- deepest brace on the shelf.
--
-- The Bastion's honest starter wall, and the shield that states the family's bargain out loud. A buckler
-- braces a little and costs nothing; this braces enormously and costs the one thing a knight normally
-- keeps, which is the option to reposition. Bracing behind it is a commitment to the square rather than
-- to the turn.
--
-- Which makes it the correct shield for exactly the job a knight is hired for -- holding a doorway,
-- standing on an objective, being the thing an enemy line has to go through -- and the wrong one for
-- anything mobile. A knight who plants this and then needs to be somewhere else has lost two turns.
--
-- The root is on the HOLDER only. It is a self-inflicted price, not a zone.
return {
    name = "Tower Shield",
    description = "Replaces Wait with Defend: a far deeper brace, but you cannot move until it lifts.",
    flavor = "The Bastion's recruits are taught to plant it before they are taught to carry it anywhere.",
    sprite = "assets/items/tower_shield.png",
    type = "armor",
    tags = { "shield" }, -- a Shield Bash item beside it in the grid can bash with it
    class = "knight",
    price = 300,
    repRank = 2,
    bonus = { defense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 } },
    resist = { physical = { 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4 } },
    -- Well above a buckler's 6-11, which is what the root buys. `status` is applied to the holder on
    -- every Defend (Combat.defend).
    waitBehavior = {
        kind = "defend",
        speed = 3,
        defense = { 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21 },
        status = "status_root",
    },
}
