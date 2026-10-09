-- ADVENTURER: the race-free Sentinel a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_sentinel@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. The knight template with a point more armour.
--
-- HE STANDS BESIDE THE HURT ONE AND TAKES HIS BLOWS (the Last Stand, the Collectors). `support` walks
-- him to the worst-off ally (models/ai.lua's `regroup`), the Warden's Oath takes the first hit each
-- turn on whoever he stands beside, and Shared Burden carries half of that ally's wounds from anywhere.
-- That is why killing him first is the counter the party page names.
return {
    name = "Sentinel",
    race = "dwarf",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/sentinel.png",
    class = "knight",
    discipline = "sentinel",
    archetype = "support",
    stats = {
        health = 72, mana = 15, stamina = 20,
        staminaRegen = 2,
        damage = 13, magicDamage = 4,
        defense = 12, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_iron_sword",  "ability_shared_burden", "armor_wardens_oath",
        "ability_safeguard",  "utility_held_line",     "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_sword",
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "ability_shared_burden",
    -- Bond the hurt one first; trade places with one about to fall; otherwise hit what is in reach.
    ai = {
        { priority = "urgent", act = "support", item = "ability_shared_burden", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.75 } },
        { priority = "high", act = "support", item = "ability_safeguard", targetPref = "most_wounded",
          when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.35 } },
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
