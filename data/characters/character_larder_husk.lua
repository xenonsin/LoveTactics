-- LARDER HUSK: the skin the Larder Mother leaves where she stood when she Moults (trait_moult). An
-- object, not a body: tier 0, no turns, no kit -- it blocks the four tiles until somebody breaks it,
-- which is the price of having spent your blows on something that was already empty.
return {
    name = "Larder Husk",
    race = "object",
    tier = 0,
    sprite = "assets/chars/larder_husk.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 30, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 4, magicDefense = 4,
        movement = 0,
        speed = 0, -- takes no turns
        skill = 0, luck = 0,
    },
    startingItems = {},
}
