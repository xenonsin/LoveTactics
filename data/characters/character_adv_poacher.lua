-- ADVENTURER: the race-free Poacher a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_poacher@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. On the rogue table, as the exemplar is; the rogue template
-- with the hunter's eye.
--
-- HE HITS ROOTED BODIES FAR HARDER (Hold and Loose, Snare Line, the Killing Ground). The Bolas Roots
-- whoever is still free; the Kris lands half again on a Rooted body; Throatcut executes one below a
-- third and hands the action back, and Thrill of the Hunt returns his turn for the kill.
return {
    name = "Poacher",
    race = "kobold",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/poacher.png",
    class = "rogue",
    discipline = "poacher",
    archetype = "aggressive",
    stats = {
        health = 58, mana = 8, stamina = 24,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 7, luck = 6,
    },
    startingItems = {
        "weapon_poachers_kris",       "ability_bolas",       "ability_throatcut",
        "utility_thrill_of_the_hunt", "armor_leather_armor", "consumable_healing_potion",
    },
    defaultAction = "weapon_poachers_kris",
    signatureWeapon  = "weapon_poachers_kris",
    signatureAbility = "ability_bolas",
    ai = {
        { priority = "urgent", act = "attack", item = "ability_throatcut", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "has_status", value = "status_root" } },
        { priority = "high", act = "attack", item = "weapon_poachers_kris",
          when = { subject = "any_foe", test = "has_status", value = "status_root" } },
        { priority = "normal", act = "attack", item = "ability_bolas",
          when = { subject = "any_foe", test = "lacks_status", value = "status_root" } },
    },
}
