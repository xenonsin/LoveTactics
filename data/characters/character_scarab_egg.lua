-- THE SCARAB EGG: what the Brood Queen lays in a coin heap (ability_lay_in_the_hoard). An object, not a
-- body that fights: it takes no turns, and in two turns (status_scarab_hatch) it splits into two Gilded
-- Scarabs. Little health and nowhere to go -- breaking it is the answer.
return {
    name = "Scarab Egg",
    race = "object",
    tier = 0,
    timeless = true,
    scaling = false,
    unarmed = false,
    sprite = "assets/chars/scarab_egg.png",
    stats = {
        health = 12, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 2, magicDefense = 2,
        movement = 0,
        speed = 0,
        skill = 0, luck = 0,
    },
    startingItems = {},
}
