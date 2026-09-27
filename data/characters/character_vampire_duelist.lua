-- THE VAMPIRE DUELIST, rung 2 (Wrath's vampires, 2026-09-26). A human duelist, and a vampire. MIST STEP: the first
-- blow it takes each round does no damage -- it turns to mist, re-forms 2 tiles away on a tile it picks, and the
-- ATTACKER Bleeds (trait_mist_step). The answer is to spend a cheap blow first: a thrown knife, a bat, a spell
-- that was going to land anyway.
--
-- A fighter on the fighter table, carrying the duelist's Main Gauche so the discipline it claims is on it.
-- Drops the Mistcloak (the same trick, once a fight, and automatic).
return {
    name = "Vampire Duelist",
    race = "human",
    tier = 2,
    class = "fighter",
    discipline = "duelist",
    vampire = true,
    sprite = "assets/chars/vampire_duelist.png",
    archetype = "skirmish",
    stats = {
        health = 50, mana = 0, stamina = 24,
        staminaRegen = 4,
        damage = 11, magicDamage = 0,
        defense = 3, magicDefense = 4,
        movement = 4,
        speed = 5,
        skill = 7, luck = 6,
    },
    startingItems = {
        "weapon_main_gauche", "utility_mist_step", "ability_wing_swap",
        "ability_feed",       false,               false,
        false,                false,               false,
    },
    drops = { "armor_mistcloak" },
    defaultAction = "weapon_main_gauche",
    signatureWeapon = "weapon_main_gauche",
}
