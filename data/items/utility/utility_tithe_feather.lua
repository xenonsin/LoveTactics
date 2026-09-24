-- TITHE FEATHER: the flight brings its take home (data/traits/trait_tithe_feather.lua). When a beast you
-- summoned strikes a foe, you recover 3 health. A Beastmaster charm off the Griffin; approved on review
-- (2026-09-23).
return {
    name = "Tithe Feather",
    description = "When a beast you summoned strikes a foe, recover 3 health.",
    flavor = "A griffin's pinion, stiff as a quill. It was given, not taken -- or so the story goes.",
    sprite = "assets/items/utility_tithe_feather.png",
    type = "utility",
    tags = { "charm", "beast" },
    class = "beastmaster",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_tithe_feather" },
}
