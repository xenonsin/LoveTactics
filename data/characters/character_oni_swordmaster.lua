-- THE ONI SWORDMASTER, rung 2: the clan's old master (approved 2026-09-26, "The Oni of Wrath"), after Reincarnated
-- as a Slime's old swordsman who draws and cuts in one motion.
--
-- INSTANT DRAW: it waits, and the first body to step into its reach is cut before it acts (its katana turns Wait into
-- Overwatch). THE LESSON: every oni within 2 of it crits 10% more often. A body that controls ground by threat rather
-- than walls -- the one Wrath body that punishes charging in.
--
-- It drops the Instant-Draw Katana. A duelist on the rogue table.
return {
    name = "Oni Swordmaster",
    race = "oni",
    tier = 3,
    class = "rogue",
    discipline = "duelist",
    sprite = "assets/chars/oni_swordmaster.png",
    archetype = "aggressive",
    stats = {
        health = 88, mana = 0, stamina = 26,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 5, magicDefense = 4,
        movement = 3,
        speed = 4,
        skill = 7, luck = 6,
    },
    startingItems = {
        "weapon_instant_draw_katana", "utility_the_lesson", "ability_en_garde",  
        false,                        false,                false,
        false,                        false,                false,
    },
    drops = { "weapon_instant_draw_katana" },
    defaultAction = "weapon_instant_draw_katana",
    signatureWeapon = "weapon_instant_draw_katana",
}
