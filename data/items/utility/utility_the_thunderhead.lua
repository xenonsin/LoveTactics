-- THE THUNDERHEAD: the storm's organ (trait_the_thunderhead; models/storm.lua). A cloud, so it FLIES -- over the
-- lava as every flier does -- and while it stands its fire carries its lightning; it drops ash, tears in two at half
-- and erupts at a third.
return {
    name = "The Thunderhead",
    description = "Fire conducts its lightning. Drops ash that blocks sight and inflicts Blind. Tears in two at half; erupts at a third.",
    flavor = "An eruption makes its own weather, and the weather is angry.",
    sprite = "assets/items/utility_the_thunderhead.png",
    type = "utility",
    tags = { "natural", "flying" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_thunderhead" },
}
