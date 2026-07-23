-- Crucible rank-2, and the cold third of the elemental trio (see armor_salamander_hide's header for
-- why all three live on the envy shelf rather than in the general store).
--
-- Ice is the control element in this catalog rather than the damage one -- Freeze delays a turn and
-- leaves the body open to impact and fire (status_freeze), Rimebitten bills extra cold on every
-- incoming hit, Cripple takes the legs. So what this coat is really bought for is not the number it
-- subtracts, it is the `statusResist` line under it: cold in this game mostly arrives as an
-- affliction, and a flat ward makes those land for a fraction of their length (Status.resistRating).
--
-- That makes it the only one of the three whose real value is not on the `resist` row, which is a
-- deviation worth naming rather than quietly tuning around. A Salamander Hide that resisted Burn's
-- duration as well would simply be strictly better than this; it does not, because fire in this game
-- is damage and cold is time.
--
-- Cloth: a square of pace.
return {
    name = "Rimecloth",
    description = "Drinks cold, and shortens the frostbitten afflictions that come with it.",
    flavor = "The Crucible keeps a bolt of it in every ice-house and replaces it on a schedule nobody argues with.",
    sprite = "assets/items/armor_rimecloth.png",
    type = "armor",
    tags = { "cloth", "ice" },
    class = "alchemist",
    price = 230,
    repRank = 2,
    bonus = {
        magicDefense = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 },
        statusResist = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 },
        movement = -1,
    },
    resist = { ice = { 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13 } },
}
