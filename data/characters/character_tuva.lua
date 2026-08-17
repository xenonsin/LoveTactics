-- Tuva, the Totemist the Hiring Hall offers. A version of the totemist exemplar
-- (data/characters/character_totemist.lua, the ward-carver), which stays put.
--
-- The Standing Stone (data/items/utility/utility_standing_stone.lua) consecrates the SHAPE her totems
-- make, so three is a very different number from two -- two are a line, three are an area. What it
-- leaves outlasts the totems, which is the whole totemist argument.
return {
    name = "Tuva",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/tuva.png",
    class = "priest",
    discipline = "totemist",
    archetype = "support",
    stats = {
        health = 84, mana = 70, stamina = 15,
        staminaRegen = 2,
        damage = 12, magicDamage = 12,
        defense = 8, magicDefense = 11,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_staff",        "ability_raise_totem",  "ability_carved_stake",
        "ability_totem_of_renewal", "utility_standing_stone", "utility_totem_carvers_kit",
        "ability_ley_line",    "consumable_healing_potion", false,
    },
    defaultAction = "ability_raise_totem",
    signatureWeapon  = "weapon_staff",
    signatureAbility = "utility_standing_stone",
    ai = {
        { priority = "high", act = "cast", item = "ability_raise_totem",
          when = { subject = "any_ally", test = "exists" } },
    },
}
