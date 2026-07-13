-- Fighter vendor. Its quest line runs through the arena and ends facing Wrath.
return {
    name = "The Colosseum",
    class = "fighter",
    sprite = "assets/vendors/colosseum.png", -- shopkeeper portrait; falls back to a placeholder
    description = "Blood, sand, and a roaring crowd. The masters here sell what wins fights.",
    -- Ascending reputation thresholds; index = rank. ranks[1] must be 0 (entry standing).
    ranks = { 0, 40, 100, 200 },
    rankNames = { "Recruit", "Contender", "Champion", "Legend" },
    sin = "wrath",
}
