-- THE ORC PIT-FIGHTER, rung 3: the orcs' alpha, in the Blood Ring (approved as pitched, 2026-09-26, "The Orcs of
-- Wrath"; Keno's reversal made the pit-fighter the alpha and the Warchief the elite).
--
-- The Blood Ring (utility_the_blood_ring): the Grunts he brings line the board's edge and shove back anyone who ends
-- a turn beside them; each turn he names the company body with the most health as his challenger and takes half
-- damage from everyone else; when a body falls, one of the crowd steps in, and when he falls they all do.
--
-- A CHAMPION on the fighter table, carrying Defiant Stand: he draws the ring's fight onto himself. The alpha of the
-- line never cowers (orcs never do). He drops the Pit-Fighter's Belt, the Challenge turned round.
return {
    name = "Orc Pit-Fighter",
    race = "orc",
    tier = 3,
    class = "fighter",
    discipline = "champion",
    sprite = "assets/chars/orc_pit_fighter.png",
    archetype = "aggressive",
    stats = {
        health = 118, mana = 0, stamina = 28,
        staminaRegen = 4,
        damage = 14, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 8, luck = 5,
    },
    startingItems = {
        "weapon_iron_greatsword", "ability_defiant_stand", "utility_the_blood_ring",
        false,                    false,                   false,
        false,                    false,                   false,
    },
    drops = { "utility_pit_fighters_belt" },
    defaultAction = "weapon_iron_greatsword",
    signatureWeapon = "weapon_iron_greatsword",
}
