-- Crucible rank-2, and the lightning third of the elemental trio (see armor_salamander_hide's header
-- for why all three live on the envy shelf rather than in the general store).
--
-- Rank 2 rather than the Hide's 1, and the extra rung is earned by what lightning DOES in this game:
-- it conducts. status_wet spreads a bolt to nearby water (see data/status/status_wet.lua), so a
-- lightning hit is the one element that reliably arrives at more than one body, and a coat that blunts
-- it is worth more than a coat that blunts the equivalent number of fire.
--
-- Which is also why it carries a small `wet` counterplay of its own and the other two do not: the
-- Stormcloth is the answer to the combination, not to the bolt.
--
-- Cloth, so it costs a square of pace -- and that is the honest reason it is not simply better than
-- the Salamander Hide beside it on the same shelf.
return {
    name = "Stormcloth",
    description = "Drinks lightning. Does nothing whatever about anything else.",
    flavor = "The Crucible weaves the earthing wire in and bills for it separately, as a courtesy.",
    sprite = "assets/items/armor_stormcloth.png",
    type = "armor",
    tags = { "cloth", "lightning" },
    class = "alchemist",
    price = 230,
    repRank = 2,
    bonus = { magicDefense = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 }, movement = -1 },
    resist = { lightning = { 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13 } },
}
