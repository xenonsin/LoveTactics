-- THE ADVENTURER BOMBARDIER ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_bombardier@<race>`; `race` is only the class's first
-- leaning race, so the bare blueprint loads.
--
-- Into the Fire, the Fuse and Green Hands all stand on its ground: Liquid Fire leaves the burning
-- crater, the Powder Keg and the Blast Charge are what the next blast sets off, and the bulwark's push
-- is what puts you there. Traffic, not the Bombardier boss: no Held Reaction, no Short Fuse.
return {
    name = "Bombardier",
    race = "goblin",
    tier = 2,
    adventurer = true,
    class = "alchemist",
    discipline = "bombardier",
    sprite = "assets/chars/bombardier.png",
    archetype = "skirmish",
    stats = {
        health = 54, mana = 45, stamina = 16,
        staminaRegen = 1,
        damage = 7, magicDamage = 12,
        defense = 5, magicDefense = 8,
        movement = 4,
        speed = 4,
        skill = 8, luck = 3,
    },
    startingItems = {
        "weapon_vitriol_wand", "ability_powder_keg", "ability_blast_charge",
        "consumable_flask_of_liquid_fire", "consumable_lightning_bomb", "utility_the_climbing_flame",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_vitriol_wand",
    signatureWeapon = "weapon_vitriol_wand",
    signatureAbility = "ability_blast_charge",
    ai = {
        { priority = "high", act = "attack", item = "consumable_flask_of_liquid_fire",
          when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        { priority = "high", act = "cast", item = "ability_powder_keg",
          when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        { priority = "normal", act = "attack", item = "ability_blast_charge", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
