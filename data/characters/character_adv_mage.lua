-- THE ADVENTURER MAGE ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_mage@<race>`; `race` is only the class's first leaning race,
-- so the bare blueprint loads.
--
-- Fire and Steel's mage lays the burning ground the alchemist throws into: Fireball leaves Fire in area
-- and the Emberwand leaves it under every bolt. The magic pair is the generic Mage's, whole -- a smaller
-- pool would be a hidden equip gate on the very spell the class is for.
return {
    name = "Mage",
    race = "human",
    tier = 1,
    adventurer = true,
    class = "mage",
    sprite = "assets/chars/gyeom.png",
    archetype = "skirmish",
    stats = {
        health = 20, mana = 80, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 2, magicDefense = 8,
        movement = 4,
        speed = 3,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_emberwand", "ability_fireball", "ability_fire_bolt",
        "armor_silk_robes", "consumable_mana_potion", "consumable_healing_potion",
    },
    defaultAction = "weapon_emberwand",
    signatureWeapon = "weapon_emberwand",
    signatureAbility = "ability_fireball",
    ai = {
        { priority = "emergency", act = "retreat", when = { subject = "self", test = "hp_pct_below", value = 0.3 } },
        { priority = "high", act = "attack", item = "ability_fireball",
          when = { subject = "any_foe", test = "count_at_least", value = 2 } },
    },
}
