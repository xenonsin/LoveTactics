-- Per-level stat gains for a character growing as a KNIGHT (sloth's class): the wall.
-- Applied by models/growth.lua on each prestige-driven level-up when this is the character's
-- most-used class. List only the stats that grow; health/mana/stamina land on the resource's `.max`.
-- See data/growth/ for the full set and docs/adding-content.md for the growth system.
return {
    health = 12,
    defense = 2,
    magicDefense = 1,
    damage = 1,
}
