-- GORGER'S BEAK: every consumable you use this fight gives you +2 Damage for the rest of it, up to three
-- (data/traits/trait_gorgers_beak.lua). The Griffin's appetite, for the Warbrewer, whose shelf is
-- draughts. Approved on review (2026-09-23).
return {
    name = "Gorger's Beak",
    description = "Each consumable you use this battle gives +2 damage for the rest of it, up to 3 times.",
    flavor = "Hooked, and polished by use. Whatever it held, it held on the way down.",
    sprite = "assets/items/utility_gorgers_beak.png",
    type = "utility",
    tags = { "charm" },
    class = "warbrewer",
    unlockLevel = 2,
    unstocked = true,
    traits = { "trait_gorgers_beak" },
}
