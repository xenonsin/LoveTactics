-- THE LAMP: the Wishmaker's (reviewed 2026-09-30, "Pride's Bestiary"). An object on the board, as the kobolds'
-- Dragon Egg is: it takes no turns (`timeless`), it does not grow with the floor (`scaling = false` -- the
-- counterplay is breaking it, and a lamp that levelled would stop being breakable), and it counts on her side, so
-- a kill-all is not won while it stands.
--
-- While it stands her wishes are granted, and after her third it is the only thing keeping her up
-- (utility_the_lamp -> trait_the_lamp). Sturdier than an egg: it is meant to cost a turn or two of somebody's
-- blows, which is the price of taking her wishes off the table.
return {
    name = "The Lamp",
    race = "object",
    tier = 0,
    timeless = true,
    scaling = false,
    unarmed = false,
    sprite = "assets/chars/the_lamp.png",
    stats = {
        health = 40, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 4, magicDefense = 6,
        movement = 0, -- it does not move
        speed = 0,    -- it takes no turns
        skill = 0, luck = 0,
    },
    startingItems = { "utility_the_lamp" },
}
