-- NINJA, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_ninja@<race>`; `race` names the first leaning race only so the blueprint
-- loads. Built on the generic rogue (the root the exemplar walks): 8 / 3 magic.
--
-- AN EVADER, AND KEPT HONEST ON PURPOSE (Hit and Gone). The companies were deleted because evasion and
-- sustain outscaled damage and fights never ended, so this body carries ONE way out of a blow at a time:
-- Vanishing Strike (strike, slip back, Invisible to the next turn), spent only on a wounded foe, and a
-- single Mirror Image the rogue's eight mana pays for once. None of the exemplar's stack -- no Smoke
-- Mantle (Invisible every quiet turn), no Substitution (a blow moved onto a clone), no Scatterlight -- and
-- the rogue's own luck, not a raised one. The page's counter stands: area spells, hazards and blasts.
return {
    name = "Ninja",
    race = "oni",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/ninja.png",
    class = "rogue",
    discipline = "ninja",
    archetype = "skirmish",
    stats = {
        health = 54, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 15, magicDamage = 3,
        defense = 5, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 8, luck = 7,
    },
    startingItems = {
        "weapon_iron_dagger", "ability_vanishing_strike", "ability_mirror_image",
        "armor_leather_armor",
    },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "ability_vanishing_strike",
    -- 1. Vanish off a wounded foe. 2. Leave the one double when a foe closes. 3. Otherwise cut.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_vanishing_strike", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        { priority = "high", act = "cast", item = "ability_mirror_image",
          when = { subject = "nearest_foe", test = "within", value = 2 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
