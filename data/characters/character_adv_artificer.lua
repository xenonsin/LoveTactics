-- ARTIFICER, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A
-- race-free body fielded as `character_adv_artificer@<race>`; `race` names the first leaning race only so
-- the blueprint loads. Built on the generic mage (the root the exemplar walks): 80 / 18 magic.
--
-- WHAT IT DOES ON THE BOARD (The Fuse, The Killing Ground, Snare Line): it sets crossbow sentries that
-- cover the lane, Overcharges them, and pecks with the wand. A sentry RESERVES a fifth of the pool, so
-- five is the most it can hold at once, and each one lapses on its own clock. It builds only while
-- nothing is in wand range, so the turrets cover the crossing rather than every turn of the fight.
return {
    name = "Artificer",
    race = "dwarf",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/artificer.png",
    class = "mage",
    discipline = "artificer",
    archetype = "skirmish",
    stats = {
        health = 46, mana = 80, stamina = 12,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 5, magicDefense = 12,
        movement = 4,
        speed = 3,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_wand", "ability_emplace_sentry", "ability_overcharge",
        "armor_silk_robes",
    },
    defaultAction = "weapon_wand",
    signatureWeapon  = "weapon_wand",
    signatureAbility = "ability_emplace_sentry",
    -- Wand what it reaches; set a sentry while a foe is still crossing toward it.
    ai = {
        { priority = "high", act = "attack", item = "weapon_wand", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
        { priority = "normal", act = "cast", item = "ability_emplace_sentry",
          when = { subject = "any_foe", test = "within", value = 6 } },
    },
}
