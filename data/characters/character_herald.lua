-- THE HERALD, rung 1: the choir's small voice (reviewed 2026-09-30, "Pride's Bestiary").
--
-- Chaff with one job: at the end of its turn every angel within 2 of it is Blessed (the Hymn, utility_the_hymn).
-- Alone it is a lamp with a short bolt; in a choir it is +5 to every blow the angels around it throw. It is the
-- body to kill first, and Incorruptible is why there is no cheaper answer -- nothing laid on the choir silences it.
-- The Throne calls two of them at every quarter of its health (Hosanna).
--
-- It drops the Herald's Trumpet, the Hymn for a company.
return {
    name = "Herald",
    race = "angel",
    tier = 1,
    sprite = "assets/chars/herald.png",
    archetype = "support",
    stats = {
        health = 24, mana = 0, stamina = 15,
        staminaRegen = 3,
        damage = 3, magicDamage = 6,
        defense = 2, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 4, luck = 2,
    },
    startingItems = {
        "weapon_choir_light", "utility_the_hymn", false,
        false,                false,              false,
        false,                false,              false,
    },
    drops = { "utility_heralds_trumpet" },
    defaultAction = "weapon_choir_light",
}
