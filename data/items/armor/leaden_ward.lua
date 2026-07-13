-- Crucible rank-2. Passive armor: a lead-lined coat the alchemists wear over everything else, because
-- what they work with does not care how brave you are. Poor against a blade, excellent against fire
-- and lightning -- the inverse of the Bastion's steel, and the reason a caster-heavy party buys here.
--
-- Lead is heavy. The movement penalty is the price of the resists.
return {
    name = "Leaden Ward",
    description = "A lead-lined coat. Drinks fire and lightning; does little against a sword.",
    sprite = "assets/items/leaden_ward.png",
    type = "armor",
    class = "alchemist",
    price = 240,
    repRank = 2,
    bonus = { magicDefense = { 7, 8, 8, 9, 10, 11, 11, 12, 13, 13, 14 }, defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 }, movement = -1 },
    resist = { fire = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 }, lightning = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 }, magical = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
}
