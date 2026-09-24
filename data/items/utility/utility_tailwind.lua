-- TAILWIND: the wyvern's defence, carried as creature kit. See data/traits/trait_tailwind.lua -- +25 Avoid
-- while no foe is beside it, and where an Alpha Wyvern's Lead the Wind lands. The company's Tailwind
-- Charm is the same trait at 15.
return {
    name = "Tailwind",
    description = "+25 Avoid while no foe is adjacent.",
    flavor = "It is not fast. It is simply never where the blow arrives.",
    sprite = "assets/items/utility_tailwind.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "wind" },
    noSteal = true,
    traits = { "trait_tailwind" },
}
