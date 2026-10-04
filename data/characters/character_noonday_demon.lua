-- THE NOONDAY DEMON: one body, on Sloth's approach ("Sloth's Bestiary", 2026-10-04, slice C). The desert fathers'
-- daemon meridianus -- acedia's own demon, who comes at midday and makes the monk look at the sun, and the door,
-- and wonder why he bothers.
--
--   LISTLESS   each foe within 4 that ends its turn having dealt no damage gains Listless (-3 Damage a stack); at
--              3 it is Shamed -- no act, no move -- on its next turn. Dealing damage clears every stack
--              (utility_noonday_haze; models/sloth_bog.lua)
--
-- THE COUNTER, STATED, and it is the review's own: everyone near it fights. The healer and the support are its
-- prey, so keep them more than 4 away from it or give them something to hit. Kill it fast. Beside the Bog-Bound
-- it is worse than either alone: a blow Past Feeling swallows dealt nothing, and the Demon counts it.
--
-- A demon, so holy finds it and its blows burn. The noon is in it: fire slides off, and the cold bites.
return {
    name = "The Noonday Demon",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/noonday_demon.png",
    stats = {
        health = 96, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 12, magicDamage = 0,
        defense = 4, magicDefense = 6,
        movement = 4,
        speed = 5,
        skill = 5, luck = 4,
    },
    resist = { fire = 3, ice = -3 },
    startingItems = {
        "weapon_heat_of_the_day", "utility_noonday_haze", false,
        false,                    false,                  false,
        false,                    false,                  false,
    },
    drops = { "utility_meridian_charm" },
    defaultAction = "weapon_heat_of_the_day",
    archetype = "aggressive",
}
