-- Ivo, the Spellbreaker the Hiring Hall offers. A version of the spellbreaker exemplar
-- (data/characters/character_spellbreaker.lua, the anti-mage sword-oath), which stays put.
--
-- The Dry Word (data/items/utility/utility_dry_word.lua) empties every silenced caster within three and
-- hands the mana to him. Empty Vessel executes the mana-dry, so the two are one engine: this makes the
-- condition the shelf is built to punish.
return {
    name = "Ivo",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/ivo.png",
    class = "knight",
    discipline = "spellbreaker",
    archetype = "guard",
    stats = {
        health = 108, mana = 15, stamina = 18,
        staminaRegen = 2,
        damage = 18, magicDamage = 4,
        defense = 14, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_silencing_blade", "ability_mana_sunder", "ability_null_field",
        "utility_dampening_oath", "utility_dry_word",    "utility_empty_vessel",
        "armor_skeptics_harness", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_silencing_blade",
    signatureWeapon  = "weapon_silencing_blade",
    signatureAbility = "utility_dry_word",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
