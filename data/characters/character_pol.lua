-- Pol, the Bombardier the Hiring Hall offers. A version of the bombardier exemplar
-- (data/characters/character_bombardier.lua, the counterfeit-bomb runner), which stays put.
--
-- The Short Fuse (data/items/utility/utility_short_fuse.lua) sets off everything he has planted at
-- once, so the relic's size is decided by how much of the fight he spent littering -- which is the
-- only thing a bombardier wants to be rewarded for.
return {
    name = "Pol",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/pol.png",
    class = "alchemist",
    discipline = "bombardier",
    archetype = "skirmish",
    stats = {
        health = 86, mana = 45, stamina = 18,
        staminaRegen = 2,
        damage = 8, magicDamage = 12,
        defense = 6, magicDefense = 9,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_vitriol_wand", "ability_powder_keg",   "ability_blast_charge",
        "ability_held_reaction", "utility_short_fuse", "consumable_acid_bomb",
        "consumable_ice_bomb", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_vitriol_wand",
    signatureWeapon  = "weapon_vitriol_wand",
    signatureAbility = "utility_short_fuse",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "exists" } },
    },
}
