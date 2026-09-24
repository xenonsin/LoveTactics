-- LEAD THE WIND: the Alpha Wyvern's, and the kill order of its flight. See data/traits/trait_lead_the_wind.lua.
return {
    name = "Lead the Wind",
    description = "Wyverns within 3 tiles gain +15 Avoid, even with a foe adjacent.",
    flavor = "The others do not follow it. They follow the air it moves.",
    sprite = "assets/items/utility_lead_the_wind.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "wind" },
    noSteal = true,
    traits = { "trait_lead_the_wind" },
}
