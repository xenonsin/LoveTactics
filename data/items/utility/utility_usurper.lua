-- USURPER: a warlord's trophy off the Hollow Crown (slice D). The Crown's seven wants were carried off by seven
-- people; worn, the bearer does the carrying -- a foe that falls near it hands over every boon it held
-- (trait_usurper).
return {
    name = "Usurper",
    description = "When a foe with boons falls within 3 of you, its boons pass to you.",
    flavor = "Every crown in the world was taken off somebody.",
    sprite = "assets/items/utility_usurper.png",
    type = "utility",
    tags = { "charm" },
    class = "warlord",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_usurper" },
}
