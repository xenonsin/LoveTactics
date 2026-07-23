-- A shield, so it swaps Wait into Defend (docs/weapons.md). Its extra is the school: bracing grants
-- status_aegis, which raises Magic Defense as well as Defense -- the only shield in the game that braces
-- against a spell.
--
-- Quest-only: `class` with no `price`.
--
-- The family's blind spot, filled. Every other shield here -- buckler, tower, Oathkeeper, Bulwark, Shared
-- Bulwark -- raises physical defense and nothing else, which means the correct way to fight a knight has
-- always been to not use a sword. A braced knight is the hardest thing on the board to stab and exactly as
-- soft as everyone else to a bolt, and until now the shelf had no answer to that at all.
--
-- Its own physical brace is under a buckler's, so it is not a strictly better shield -- it is a narrower
-- one that covers both schools shallowly instead of one deeply. Against a warband of swords it is the
-- worst shield on the rack. Against the Arcanum it is the only one.
--
-- Note it is the one shield here whose extra is a plain BIGGER NUMBER rather than a new verb, and that is
-- deliberate: a number in a stat the family could not previously touch is a different thing from a number
-- in the stat it already had. The deviation is which bar it fills, not how full.
return {
    name = "The Aegis Unbidden",
    description = "Replaces Wait with Defend: brace against spells as well as steel -- the only shield that does.",
    flavor = "The Cathedral gave it to the Bastion without being asked, which is how it got the name and most of the argument.",
    sprite = "assets/items/aegis_unbidden.png",
    type = "armor",
    tags = { "shield", "holy" },
    class = "knight",
    bonus = { defense = { 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6 } },
    -- The only shield carrying a magical resist, which is half of what makes it worth the slot before it
    -- is ever planted.
    resist = { magical = { 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5 } },
    waitBehavior = {
        kind = "defend",
        speed = 3,
        -- Under a buckler's 6-11: the Aegis below is what the difference bought.
        defense = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 },
        status = "status_aegis",
    },
}
