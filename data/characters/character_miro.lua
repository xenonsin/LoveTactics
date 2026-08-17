-- Miro, the Ninja the Hiring Hall offers. A version of the ninja exemplar
-- (data/characters/character_ninja.lua, The Shadowless). Kaen stays the marquee boss of the unlock
-- quest; Miro is the body you can actually hire.
--
-- The Fourth Shadow (data/items/utility/utility_fourth_shadow.lua) counts clones STANDING and then
-- doubles them, so every clone put out before pressing it is worth two -- and Substitution, which
-- spends one to eat a blow, is a real cost against the gate.
return {
    name = "Miro",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/miro.png",
    class = "rogue",
    discipline = "ninja",
    archetype = "skirmish",
    stats = {
        health = 92, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 19, magicDamage = 3,
        defense = 8, magicDefense = 9,
        movement = 4,
        speed = 6,
    },
    startingItems = {
        "weapon_iron_dagger",  "ability_mirror_image", "ability_scatterlight",
        "ability_vanishing_strike", "utility_fourth_shadow", "utility_substitution",
        "armor_smoke_mantle",  "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon  = "weapon_iron_dagger",
    signatureAbility = "utility_fourth_shadow",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
