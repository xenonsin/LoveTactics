-- THE TROPHY CORD: +2 Damage for each different kind of foe you have killed this trip, up to +10
-- (data/traits/trait_trophy_cord.lua). Rengar's Bonetooth Necklace, by way of the Sabertooth -- pitched at
-- +1 / +5 in round two, "too underpowered", and approved doubled in round three.
--
-- HUNTER STOCK: the Lodge's pieces pay for knowing what you are hunting, and this one pays for having
-- hunted everything. It empties when the company comes back through the Gate (Player.clearTrophies).
return {
    name = "Trophy Cord",
    description = "+2 Damage for each different kind of foe you have killed this trip, up to +10.",
    flavor = "One knot for every kind of thing. Nobody who wears one ties the same knot twice.",
    sprite = "assets/items/utility_trophy_cord.png",
    type = "utility",
    tags = { "beast" },
    class = "hunter",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_trophy_cord" },
}
