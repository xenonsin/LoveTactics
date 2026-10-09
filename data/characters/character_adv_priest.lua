-- THE ADVENTURER PRIEST ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_priest@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- Field Dressing's priest heals the front and wards its ground: Heal on the worst-off, Sanctuary under
-- whoever is trading. It is the one sustain body its party is allowed, and the page's counter is to
-- reach past the front to it -- so it stands back and reads its allies first.
return {
    name = "Priest",
    race = "human",
    tier = 1,
    adventurer = true,
    class = "priest",
    sprite = "assets/chars/xin.png",
    archetype = "support",
    stats = {
        health = 22, mana = 70, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 12,
        defense = 3, magicDefense = 7,
        movement = 4,
        speed = 3,
        skill = 3, luck = 6,
    },
    startingItems = {
        "weapon_censer", "ability_heal", "ability_sanctuary",
        "armor_silk_robes", "consumable_healing_potion",
    },
    defaultAction = "weapon_censer",
    signatureWeapon = "weapon_censer",
    signatureAbility = "ability_heal",
    ai = {
        { priority = "urgent", act = "support", item = "ability_heal", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.65 } },
        { priority = "high", act = "support", item = "ability_sanctuary",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.9 } },
    },
}
