-- Nio, the Elementalist the Hiring Hall offers. A version of the elementalist exemplar
-- (data/characters/character_elementalist.lua), which stays where it is.
--
-- The Ninth Sigil (data/items/utility/utility_ninth_sigil.lua) copies the ground he has laid beneath
-- every foe, so his three sigil modifiers are the gate AND the payload -- what a circle cut in the
-- floor cannot do is go looking, and that is the one thing the relic adds.
return {
    name = "Nio",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/nio.png",
    class = "mage",
    discipline = "elementalist",
    archetype = "skirmish",
    stats = {
        health = 86, mana = 80, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 4, magicDefense = 13,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_graven_circle_staff", "ability_blizzard",      "utility_twinned_sigil",
        "utility_quickened_sigil",    "utility_ninth_sigil",   "utility_distant_sigil",
        "armor_silk_robes",           "consumable_healing_potion", false,
    },
    defaultAction = "ability_blizzard",
    signatureWeapon  = "weapon_graven_circle_staff",
    signatureAbility = "utility_ninth_sigil",
    ai = {
        { priority = "high", act = "cast", item = "ability_blizzard", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
