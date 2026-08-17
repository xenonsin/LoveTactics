-- Wick, the Artificer the Hiring Hall offers. A version of the artificer exemplar
-- (data/characters/character_artificer.lua, the sentry-engine builder), which stays put.
--
-- The Standing Order (data/items/utility/utility_standing_order.lua) upgrades every construct and the
-- upgrades STACK, which is the one place the repeatable-versus-once call has teeth. Salvage Rig and
-- Recall Construct matter far more once the census is the thing he is protecting.
return {
    name = "Wick",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/wick.png",
    class = "mage",
    discipline = "artificer",
    archetype = "skirmish",
    stats = {
        health = 88, mana = 80, stamina = 14,
        staminaRegen = 1,
        damage = 8, magicDamage = 18,
        defense = 7, magicDefense = 10,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_staff",        "ability_emplace_sentry", "ability_field_assembly",
        "ability_overcharge",  "utility_standing_order", "utility_salvage_rig",
        "ability_recall_construct", "consumable_healing_potion", false,
    },
    defaultAction = "ability_emplace_sentry",
    signatureWeapon  = "weapon_staff",
    signatureAbility = "utility_standing_order",
    ai = {
        { priority = "high", act = "cast", item = "ability_emplace_sentry",
          when = { subject = "any_foe", test = "exists" } },
    },
}
