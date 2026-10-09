-- THE ADVENTURER ELEMENTALIST ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua).
-- A race-free body: fielded as `character_adv_elementalist@<race>`; `race` is only the class's first
-- leaning race, so the bare blueprint loads.
--
-- Cuts the Graven Circle first and casts from inside it, with the grid's sigils reshaping the Blizzard
-- beside them -- twinned, farther. The magic pair is the generic Mage's, whole. What the engine does not
-- do is let a sigil serve ANOTHER body's spell (the circle's own flavor: "it will not do a thing for
-- them"), so the Sigil Choir's mage and priest cast plain; the gap is reported.
return {
    name = "Elementalist",
    race = "elf",
    tier = 2,
    adventurer = true,
    class = "mage",
    discipline = "elementalist",
    sprite = "assets/chars/elementalist.png",
    archetype = "skirmish",
    stats = {
        health = 44, mana = 80, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 4, magicDefense = 13,
        movement = 4,
        speed = 3,
        skill = 6, luck = 4,
    },
    -- The Distant and Twinned Sigils both touch the Blizzard (cell 2) in the grid.
    startingItems = {
        "utility_distant_sigil", "ability_blizzard", "utility_twinned_sigil",
        "weapon_graven_circle_staff", "ability_graven_circle", "armor_silk_robes",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_graven_circle_staff",
    signatureWeapon = "weapon_graven_circle_staff",
    signatureAbility = "ability_graven_circle",
    ai = {
        { priority = "emergency", act = "retreat", when = { subject = "self", test = "hp_pct_below", value = 0.3 } },
        { priority = "high", act = "support", item = "ability_graven_circle",
          when = { subject = "self", test = "lacks_status", value = "status_graven" } },
        { priority = "high", act = "attack", item = "ability_blizzard",
          when = { subject = "any_foe", test = "count_at_least", value = 2 } },
    },
}
