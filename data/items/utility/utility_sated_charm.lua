-- SATED: being full, as generosity, for the Paladin (data/traits/trait_sated.lua). At full health, a heal
-- meant for you goes to the most hurt ally beside you. The deepest of the Sated's pieces; approved on
-- review (2026-09-23).
return {
    name = "Sated",
    description = "At full health, heals meant for you go to the most hurt ally beside you.",
    flavor = "I have had enough. Here.",
    sprite = "assets/items/utility_sated_charm.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "paladin",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_sated" },
}
