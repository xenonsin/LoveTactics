-- Ondo, the Shaman the Hiring Hall offers. A version of the shaman exemplar
-- (data/characters/character_shaman.lua, the spirit-caller), which stays put.
--
-- The Old Wind (data/items/utility/utility_old_wind.lua) raises a spirit from every hazard on the
-- board, whoever laid it -- which is the difference from Nio's Ninth Sigil. Nio copies his own workings
-- outward; Ondo wakes what is already there, because a shaman does not own the weather.
return {
    name = "Ondo",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/ondo.png",
    class = "mage",
    discipline = "shaman",
    archetype = "skirmish",
    stats = {
        health = 88, mana = 80, stamina = 16,
        staminaRegen = 2,
        damage = 14, magicDamage = 18,
        defense = 8, magicDefense = 10,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_staff",        "ability_call_spirit",  "ability_bind_spirit",
        "utility_ancestor_mask", "utility_old_wind",   "utility_spirit_fetish",
        "utility_ghost_wind",  "consumable_healing_potion", false,
    },
    defaultAction = "ability_call_spirit",
    signatureWeapon  = "weapon_staff",
    signatureAbility = "utility_old_wind",
    ai = {
        { priority = "high", act = "cast", item = "ability_call_spirit",
          when = { subject = "any_foe", test = "exists" } },
    },
}
