-- Dov, the Bulwark the Hiring Hall offers. A version of the bulwark exemplar
-- (data/characters/character_bulwark.lua, the Road-Captain), which stays where it is.
--
-- He carries Doorstone (data/items/utility/utility_doorstone.lua), which is deliberately NOT Rowan's
-- verb: it raises a wall rather than shoving a ring, so the shortest way to whatever he stands in front
-- of stops existing. The rest of the grid is the shelf that punishes the queue it makes.
return {
    name = "Dov",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/dov.png",
    class = "knight",
    discipline = "bulwark",
    archetype = "defensive",
    stats = {
        health = 112, mana = 15, stamina = 18,
        staminaRegen = 2,
        damage = 15, magicDamage = 4,
        defense = 16, magicDefense = 8,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_mace",   "ability_push",        "ability_shout",
        "ability_closed_ring", "utility_doorstone",  "utility_rooted_stance",
        "armor_halting_rank", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_mace",
    signatureWeapon  = "weapon_iron_mace",
    signatureAbility = "utility_doorstone",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
