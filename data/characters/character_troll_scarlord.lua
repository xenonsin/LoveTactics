-- THE TROLL SCARLORD, rung 3 (approved 2026-10-04, "Sloth's Bestiary", slice B): "the troll that learned what burns
-- it. Indifferent, like every troll."
--
-- SCARRING BLOWS: a body its club strikes cannot be healed or regrow until the Scarlord's next turn. The club lays
-- the Unclosing Wound on the hit (weapon_scarlords_club) and the organ lifts it as the Scarlord's next turn opens
-- (utility_scarring_blows), so the window is one of its turns long. The answer is the review's: heal before it
-- swings, not after, or keep the wounded out of its reach.
--
-- An elite's three pieces: the club, the organ and a leather coat. It drops the Scarring Club (fighter).
return {
    name = "Troll Scarlord",
    race = "troll",
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/troll_scarlord.png",
    archetype = "aggressive",
    stats = {
        health = 130, mana = 0, stamina = 32,
        staminaRegen = 4,
        damage = 14, magicDamage = 0,
        defense = 6, magicDefense = 3,
        movement = 4,
        speed = 3,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_scarlords_club", "utility_scarring_blows", "armor_leather_armor",
        false,                   false,                    false,
        false,                   false,                    false,
    },
    drops = { "weapon_scarring_club" },
    defaultAction = "weapon_scarlords_club",
    signatureWeapon = "weapon_scarlords_club",
}
