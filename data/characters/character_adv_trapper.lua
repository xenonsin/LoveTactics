-- ADVENTURER: the race-free Trapper a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_trapper@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. The archer template, a little sturdier.
--
-- HE LAYS THE APPROACH BEFORE YOU GET THERE (Snare Line, the Killing Ground, the Fuse). The Caltrop
-- Greaves are what does it on the board: every tile he leaves turns against you, and he is a kiter, so
-- he leaves a lot of them. The Bear Trap rides in the kit as his verb, but no rule names it -- a hostile
-- placement lands nothing on the turn it is set, and models/ai.lua's outcome gate refuses it.
return {
    name = "Trapper",
    race = "kobold",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/trapper_ambusher.png",
    class = "hunter",
    discipline = "trapper",
    archetype = "skirmish",
    stats = {
        health = 56, mana = 15, stamina = 25,
        staminaRegen = 2,
        damage = 15, magicDamage = 3,
        defense = 5, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_iron_bow",     "ability_bear_trap",  "utility_caltrop_greaves",
        "utility_trap_sense",  "armor_leather_armor", "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_bow",
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_bear_trap",
    ai = {
        { priority = "normal", act = "attack", item = "weapon_iron_bow", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
