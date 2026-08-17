-- Zosia, the Poisoner the Hiring Hall offers. A version of the poisoner exemplar
-- (data/characters/character_poisoner.lua, the vat-master), which stays put.
--
-- The Mother Vat (data/items/utility/utility_mother_vat.lua) counts poisoned bodies rather than
-- poisonings, so the Miasma Flask is not a convenience in her grid -- it is how five of them come to be
-- carrying it at the SAME time, which is the only way the relic ever opens.
return {
    name = "Zosia",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/zosia.png",
    class = "alchemist",
    discipline = "poisoner",
    archetype = "skirmish",
    stats = {
        health = 90, mana = 45, stamina = 18,
        staminaRegen = 2,
        damage = 15, magicDamage = 12,
        defense = 7, magicDefense = 9,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_envenomed_kris", "consumable_envenom",  "consumable_crawler_mucus",
        "consumable_thinblood_rime", "utility_mother_vat", "utility_miasma_flask",
        "utility_spiteful_ichor", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_envenomed_kris",
    signatureWeapon  = "weapon_envenomed_kris",
    signatureAbility = "utility_mother_vat",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
