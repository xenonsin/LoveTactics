-- THE WISHMAKER: Pride's seat elite (reviewed 2026-09-30, "Pride's Bestiary"). An elf archmage who found the last
-- lamp on the spire and has been wishing on it ever since.
--
-- AN ELF, SO SHE OPENS UNBLEMISHED (data/races/elf.lua): the first blow to draw her blood takes the lift off her
-- spells for the rest of the fight. Her kit is the mage shelf's -- a wand, the two bolts and a Fireball.
--
-- THREE WISHES (utility_three_wishes, models/djinn.lua). Her Lamp (character_the_lamp) is a body on the board,
-- set down beside her at the bell, and while it stands it grants a wish at each third of her health:
--   2/3  she is whole again
--   1/3  she takes the company's strongest boon
--   0    she becomes a Great Djinn, held at 1 health by Lamp-Bound for as long as the Lamp stands
-- Break the Lamp before the third and she never turns; break it after and she can fall. Either way the Lamp is
-- the fight, and WHEN to break it is the decision -- the heal at two-thirds is the cheapest one to let her have.
--
-- `boss`: an objective off the execute table, carried across the turn (Djinn.grantWish, as the Gilt Wyrm's is).
-- She drops The Last Lamp.
return {
    name = "The Wishmaker",
    race = "elf",
    tier = 3,
    class = "mage",
    boss = true,
    sprite = "assets/chars/the_wishmaker.png",
    archetype = "skirmish",
    stats = {
        health = 118, mana = 64, stamina = 14,
        staminaRegen = 2, manaRegen = 5,
        damage = 4, magicDamage = 13,
        defense = 4, magicDefense = 8,
        movement = 4,
        speed = 4,
        skill = 6, luck = 6,
    },
    startingItems = {
        "weapon_wand",         "ability_fire_bolt", "ability_ice_bolt",
        "ability_fireball",    "utility_three_wishes", false,
        false,                 false,               false,
    },
    drops = { "utility_the_last_lamp" },
    defaultAction = "weapon_wand",
    signatureWeapon = "weapon_wand",
}
