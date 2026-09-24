-- HEARTH HUNGER: the Chimera's lion rebuilt for a person (trait_hearth_hunger). Weapon blows deal +3 to a
-- Burning foe -- a point under the lion's +4, because a person picks when to cash the setup in.
--
-- BATTLEMAGE STOCK, moved there on review ("Hunter wrong class"): "casts with the swing" is exactly cook
-- then eat -- the fire and the blade in one hand. Off the Chimera, the common one; it drops whether or not
-- a head was broken, because the lion is the body and the body is always killed.
return {
    name = "Hearth Hunger",
    description = "Increase weapon damage by 3 against a Burning foe.",
    flavor = "Nobody has ever been cooked for the lion's sake. That is simply how it has always turned out.",
    sprite = "assets/items/utility_hearth_hunger.png",
    type = "utility",
    tags = { "fire" },
    class = "battlemage",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_hearth_hunger" },
}
