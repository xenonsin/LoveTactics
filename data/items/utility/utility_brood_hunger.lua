-- BROOD HUNGER: the spiderlings' Engorge (trait_engorge, unchanged). When a sibling falls near one, the
-- survivor feeds -- kill them one at a time, next to each other, and whichever is left is the strongest.
return {
    name = "Brood Hunger",
    description = "Whenever anything falls nearby, it feeds and heals.",
    flavor = "There were more of them. There are fewer now, and the ones left are larger.",
    sprite = "assets/items/utility_brood_hunger.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_engorge" },
}
