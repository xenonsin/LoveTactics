-- Ilan, the Theurge the Hiring Hall offers. A version of the theurge exemplar
-- (data/characters/character_theurge.lua, the channelling divine), which stays put.
--
-- The Unbroken Vigil (data/items/utility/utility_unbroken_vigil.lua) is a prayer nothing can break
-- whose depth the PLAYER chooses on the existing wind-up slider -- and when it lands both sides of the
-- board pay for the waiting, in opposite directions. Litany Staff scales with the same number twice.
return {
    name = "Ilan",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/ilan.png",
    class = "priest",
    discipline = "theurge",
    archetype = "support",
    stats = {
        health = 82, mana = 70, stamina = 10,
        staminaRegen = 2,
        damage = 5, magicDamage = 12,
        defense = 6, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_litany_staff", "ability_invocation",   "ability_the_long_prayer",
        "ability_benediction", "utility_unbroken_vigil", "utility_vigil_beads",
        "utility_second_utterance", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_litany_staff",
    signatureWeapon  = "weapon_litany_staff",
    signatureAbility = "utility_unbroken_vigil",
    ai = {
        { priority = "high", act = "cast", item = "ability_invocation",
          when = { subject = "any_foe", test = "exists" } },
    },
}
