-- SILKFOOT: the spider line's feet (trait_silkfoot). A strand does not catch its bearer; standing on one
-- it acts sooner (status_on_the_web), and the AI routes onto web instead of around it.
return {
    name = "Silkfoot",
    description = "Walks Web freely, and moves farther and acts quicker while standing on it.",
    flavor = "The glade is a floor to you and a trap to them, and it is the same glade.",
    sprite = "assets/items/utility_silkfoot.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "silk" },
    noSteal = true,
    traits = { "trait_silkfoot" },
}
