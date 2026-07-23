-- Crucible rank-1, and one of three plain elemental coats (with armor_stormcloth and armor_rimecloth)
-- that exist to fix a real hole: fire, lightning and ice have been damage tags since the beginning and
-- almost nothing in the catalog resisted any of them. The whole counterplay to an element was the
-- Leaden Ward, at rank 2, on this same shelf.
--
-- ON THE ALCHEMIST'S SHELF rather than the general store, and the reason is what a hazard IS in this
-- game: fire, ice and lightning are overwhelmingly things the Crucible makes -- a bomb, a stone, a
-- coating, a spilled reagent. The house that sells you the burning is the house that sells you the
-- coat, which is the most alchemical arrangement available and is exactly the envy shelf's voice
-- (docs/classes.md: it covets others' power rather than casting its own -- including the power to
-- have started the fire).
--
-- No trait, no aura, no hazard. Deliberately the dullest item in this batch: a shelf needs a floor of
-- things whose whole answer is a number, or every choice is a build decision and none of them is a
-- purchase. Rank 1 and cheap, so it is available on a first visit.
--
-- Hide, not cloth: no movement penalty. This is the item a player buys when their party is already
-- slowing down under everything else, which is the point of tuning it here.
return {
    name = "Salamander Hide",
    description = "Drinks fire. Does nothing whatever about anything else.",
    flavor = "The Crucible sells the bombs on the next shelf along and has never seen the arrangement as a problem.",
    sprite = "assets/items/armor_salamander_hide.png",
    type = "armor",
    tags = { "hide", "fire" },
    class = "alchemist",
    price = 190,
    repRank = 1,
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 5, 6, 6, 7, 7 } },
    resist = { fire = { 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13 } },
}
