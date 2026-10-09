-- SKIRMISHER, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A
-- race-free body fielded as `character_adv_skirmisher@<race>`; `race` names the first leaning race only so
-- the blueprint loads. Built on the generic archer (the hunter root the exemplar walks): 15 / 3 magic.
--
-- AN EVADER BY FOOTWORK, NOT BY AVOID (Hit and Gone). The Harrier's Bow fires without ending the turn, so
-- it shoots and then walks; Harrying Strike cuts and slips back out of reach; Momentum pays its first
-- strike after moving. Nothing here makes a blow miss -- no Tailwind Charm, no Wight's Shroud, no In and
-- Out -- and it wears no armour, so what it buys in distance it pays for in defense. A blow that reaches
-- it lands in full.
return {
    name = "Skirmisher",
    race = "kobold",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/skirmisher.png",
    class = "hunter",
    discipline = "skirmisher",
    archetype = "skirmish",
    stats = {
        health = 54, mana = 15, stamina = 24,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 4, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_harriers_bow", "ability_harrying_strike", "utility_skirmishers_momentum",
    },
    defaultAction = "weapon_harriers_bow",
    signatureWeapon  = "weapon_harriers_bow",
    signatureAbility = "ability_harrying_strike",
    -- Cut and slip back off whoever is on it; otherwise shoot and keep the move.
    ai = {
        { priority = "high", act = "attack", item = "ability_harrying_strike", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
        { priority = "normal", act = "attack", item = "weapon_harriers_bow", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
