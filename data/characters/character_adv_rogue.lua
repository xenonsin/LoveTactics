-- THE ADVENTURER ROGUE ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_rogue@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- Exploit is the conditional strike Hold and Loose is built on: double on an afflicted body, more per
-- further debuff, so a body the knight Halted and the dagger Bled is the one it goes for. The Contract
-- asks it to bleed, the Collectors to steal: Drain Mana is the rogue shelf's own theft.
return {
    name = "Rogue",
    race = "goblin",
    tier = 1,
    adventurer = true,
    class = "rogue",
    sprite = "assets/chars/clem.png",
    archetype = "skirmish",
    stats = {
        health = 24, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 9, magicDamage = 3,
        defense = 3, magicDefense = 3,
        movement = 4,
        speed = 5,
        skill = 8, luck = 7,
    },
    -- Exploit sits beside the dagger it needs (requiresAdjacent).
    startingItems = {
        "weapon_iron_dagger", "ability_exploit", "ability_shadow_step",
        "armor_leather_armor", "ability_drain_mana", "consumable_ball_bearings",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
    signatureAbility = "ability_exploit",
    ai = {
        -- The held body first: it cannot step away from the multiple.
        { priority = "high", act = "attack", item = "ability_exploit",
          when = { subject = "any_foe", test = "has_status", value = "status_halted" } },
        { priority = "high", act = "attack", item = "ability_exploit",
          when = { subject = "any_foe", test = "has_status", value = "status_bleed" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
