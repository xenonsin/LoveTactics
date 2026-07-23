-- A shield, so it swaps Wait into Defend (docs/weapons.md). Its extra is that the brace SWALLOWS: planting
-- it grants status_kept_wound, which absorbs the next few physical blows entirely and then gives back
-- everything it swallowed at once when it ends.
--
-- Quest-only: `class` with no `price`.
--
-- A delayed wall, and the only defensive item in the game that is also a countdown. What it buys is the
-- shape of the damage rather than the amount: three blows that would have arrived across three turns
-- arrive together on one, which is either the best thing that could happen to a knight or the worst,
-- depending entirely on whether the priest is ready.
--
-- The correct play is to brace, eat an enemy alpha strike for nothing, and then be healed to full before
-- the wound comes due -- so it converts an unsurvivable burst into a healing check the party can prepare
-- for. The incorrect play is to brace and then have the healer die, at which point the shield kills its
-- own holder with damage they had already survived.
--
-- Read against data/items/weapon/weapon_sealed_hour.lua, which does the same thing to an ENEMY off a
-- greatsword. Same machinery, opposite ends: that one schedules a kill, this one schedules a rescue.
--
-- It answers physical blows only, so a spell goes straight through the stance and lands on time.
return {
    name = "Shield of the Kept Wound",
    description = "Replaces Wait with Defend: swallow the next few blows entirely, then take all of it at once.",
    flavor = "The Bastion's field surgeons ask that whoever is carrying it tells them beforehand.",
    sprite = "assets/items/kept_wound_shield.png",
    type = "armor",
    tags = { "shield" },
    class = "knight",
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 } },
    resist = { physical = { 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4 } },
    waitBehavior = {
        kind = "defend",
        speed = 3,
        -- Under a buckler's: the stance is not really about the flat bonus, and a knight who is relying
        -- on the number rather than the swallow has picked the wrong shield.
        defense = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 },
        status = "status_kept_wound",
    },
}
