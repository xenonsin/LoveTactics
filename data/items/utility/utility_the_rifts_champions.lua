-- THE RIFT'S CHAMPIONS: the Faceless Champion's organ (data/characters/character_faceless_champion.lua). Reviewed
-- 2026-10-01..03 ("Envy's Bestiary", round 2). Its hand is the rift's champions, each worn with its signature
-- rule, and it wears whichever answers the nearest foe (data/traits/trait_the_rifts_champions.lua). Bound and
-- unstealable, and carried into every face it wears.
return {
    name = "The Rift's Champions",
    description = "Its hand is the rift's champions, each with its signature rule. It wears the one that answers you.",
    flavor = "Every champion you have beaten, beaten by it first.",
    sprite = "assets/items/utility_the_rifts_champions.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_rifts_champions" },
}
