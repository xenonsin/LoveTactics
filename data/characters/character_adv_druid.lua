-- ADVENTURER: the race-free Druid a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_druid@<race>` (models/adventurers.lua); `race` below is only the class's first leaning
-- race, so the base blueprint loads. The archer template leaned toward the front it takes in a shape.
--
-- SHE TAKES BEAR SHAPE AND HOLDS THE FRONT (Raise the Fallen). Once the enemy is close she wears the
-- bear; until then the bow, and the Thorn Whip to haul a body to her side. The mana is the archer's
-- whole: the shape reserves a share of it, so a druid with no pool could not change at all.
--
-- THE BEAR RULE DOES NOT FIRE YET, and the exemplar's does not either. The dry run Combat.previewAbility
-- takes of a self-transform reports nothing done (no status, no `mutates`), so models/ai.lua's outcome
-- gate refuses it and she fights with the bow and the whip. The rule is the shape her turn should
-- have, and it will hold the moment the preview learns what a transform does.
return {
    name = "Druid",
    race = "elf",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/druid.png",
    class = "hunter",
    discipline = "druid",
    archetype = "aggressive",
    stats = {
        health = 60, mana = 15, stamina = 23,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 4,
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_iron_bow",     "ability_wild_shape_bear", "ability_thorn_whip",
        "armor_stalkers_pelt", "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_bow",
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_wild_shape_bear",
    ai = {
        { priority = "high", act = "cast", item = "ability_wild_shape_bear",
          when = { subject = "nearest_foe", test = "within", value = 3 } },
        { priority = "normal", act = "attack", item = "ability_thorn_whip", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "within", value = 3 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
