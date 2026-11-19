-- SHOULDERING: the Orc Grunt's organ (trait_shouldering; 2026-11-19, the creature identity pass). A foe that ends
-- its turn beside a Grunt is shoved a tile back -- the Blood Ring crowd's shove, on every board. Bound and
-- unstealable: a Grunt's own weight, not kit. The Grunt still drops Orc Scars.
return {
    name = "Shouldering",
    description = "A foe that ends its turn beside it is shoved 1 tile back.",
    flavor = "It does not step aside. It never learned that there was an aside.",
    sprite = "assets/items/utility_shouldering.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_shouldering" },
}
