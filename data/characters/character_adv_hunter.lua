-- THE ADVENTURER HUNTER ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_hunter@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- The hunter is in more parties than anybody, and in every one of them it does the same job from the
-- back: Mark a body, Called Shot it for double, Hobbling Shot whatever the knight is holding. It is
-- also the counter most of those pages name -- fragile, standing still, doing the real damage.
return {
    name = "Hunter",
    race = "elf",
    tier = 1,
    adventurer = true,
    class = "hunter",
    sprite = "assets/chars/kaya.png",
    archetype = "skirmish",
    stats = {
        health = 22, mana = 15, stamina = 23,
        staminaRegen = 2,
        damage = 10, magicDamage = 3,
        defense = 2, magicDefense = 3,
        movement = 4,
        speed = 5,
        skill = 8, luck = 4,
    },
    -- Every shot the bow powers touches it in the grid (requiresAdjacent): Mark and Called Shot beside
    -- it, Hobbling Shot under it.
    startingItems = {
        "ability_mark_target", "weapon_iron_bow", "ability_called_shot",
        "armor_leather_armor", "ability_hobbling_shot", "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_bow",
    signatureWeapon = "weapon_iron_bow",
    signatureAbility = "ability_mark_target",
    ai = {
        { priority = "high", act = "attack", item = "ability_called_shot",
          when = { subject = "any_foe", test = "has_status", value = "status_mark" } },
        -- Cripple the body somebody else is holding.
        { priority = "high", act = "attack", item = "ability_hobbling_shot",
          when = { subject = "any_foe", test = "has_status", value = "status_halted" } },
        { priority = "normal", act = "attack", item = "ability_mark_target",
          when = { subject = "any_foe", test = "lacks_status", value = "status_mark" } },
    },
}
