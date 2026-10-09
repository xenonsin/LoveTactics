-- THE ADVENTURER ALCHEMIST ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_alchemist@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- Three parties ask the same two things of it: throw a bomb into the ground somebody else lit, and
-- hand the front body an elixir that raises its blow (Giant's Vigour) -- the Last Stand's barbarian,
-- Fire and Steel's fighter. Heroism is the second draught, for the body that must not be Halted.
return {
    name = "Alchemist",
    race = "kobold",
    tier = 1,
    adventurer = true,
    class = "alchemist",
    sprite = "assets/chars/ren.png",
    archetype = "skirmish",
    stats = {
        health = 22, mana = 45, stamina = 14,
        staminaRegen = 1,
        damage = 6, magicDamage = 12,
        defense = 3, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 7, luck = 3,
    },
    startingItems = {
        "weapon_apothecarys_lancet", "consumable_fire_bomb", "consumable_elixir_of_the_giant",
        "armor_leather_armor", "consumable_elixir_of_heroism", "consumable_healing_potion",
    },
    defaultAction = "weapon_apothecarys_lancet",
    signatureWeapon = "weapon_apothecarys_lancet",
    signatureAbility = "consumable_fire_bomb",
    ai = {
        { priority = "high", act = "support", item = "consumable_elixir_of_the_giant",
          when = { subject = "nearest_ally", test = "lacks_status", value = "status_giants_vigour" } },
        { priority = "high", act = "attack", item = "consumable_fire_bomb",
          when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        { priority = "normal", act = "support", item = "consumable_elixir_of_heroism",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.6 } },
    },
}
