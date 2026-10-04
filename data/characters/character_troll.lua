-- THE TROLL, rung 2: the line body of the meltwater bridges (approved 2026-10-04, "Sloth's Bestiary", slice B).
--
-- "A heavy club that hits hard and slow. Indifferent." The race and a club, and nothing else: the body every other
-- troll is read against. Indifferent (granted by the race) is the whole lesson -- it never dodges, and every wound
-- it is given time to sleep on regrows unless it burned. Fire, then burst.
--
-- The fighter table, as the orc and oni line bodies are: a lighter table lags the enemy scaling at depth. It drops
-- both of the line's troll pieces -- the author spread them across the line -- the Apothecary's Troll Blood and the
-- Plague Knight's Grafted Troll Arm.
return {
    name = "Troll",
    race = "troll",
    tier = 2,
    class = "fighter",
    sprite = "assets/chars/troll.png",
    archetype = "aggressive",
    stats = {
        health = 64, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 4,
        speed = 2, -- slow: it hits hard and comes around late
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_troll_club", false, false,
        false,               false, false,
        false,               false, false,
    },
    drops = { "consumable_troll_blood", "utility_grafted_troll_arm" },
    defaultAction = "weapon_troll_club",
    signatureWeapon = "weapon_troll_club",
}
