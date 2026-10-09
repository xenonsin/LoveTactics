-- THE ADVENTURER BULWARK ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_bulwark@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- The immovable wall that moves everyone else, and in four parties that is the whole job: push a body
-- onto the trapper's snares, the bombardier's craters, the saboteur's charges, and Halt it there. The
-- shove's target is chosen by `hazardous` (models/ai.lua), because a burn that lands on the victim's
-- next tick is invisible to the dry run that scores the push. The Unheld keeps him where he stands.
return {
    name = "Bulwark",
    race = "dwarf",
    tier = 2,
    adventurer = true,
    class = "knight",
    discipline = "bulwark",
    sprite = "assets/chars/bulwark.png",
    archetype = "defensive",
    stats = {
        health = 64, mana = 15, stamina = 20,
        staminaRegen = 2,
        damage = 13, magicDamage = 4,
        defense = 9, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_iron_mace", "ability_push", "ability_stand_down",
        "armor_halting_rank", "ability_pull", "utility_the_unheld",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_mace",
    signatureWeapon = "weapon_iron_mace",
    signatureAbility = "ability_push",
    ai = {
        -- Onto bad ground first; then hold whoever landed there.
        -- Push scores only where it lands a collision; on open ground the mace's own Knockback 2 is
        -- the shove, and the same preference aims it.
        { priority = "high", act = "cast", item = "ability_push", targetPref = "hazardous",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "high", act = "attack", item = "weapon_iron_mace", targetPref = "hazardous",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "high", act = "cast", item = "ability_pull", targetPref = "hazardous",
          when = { subject = "any_foe", test = "within", value = 4 } },
        { priority = "normal", act = "attack", item = "ability_stand_down",
          when = { subject = "any_foe", test = "lacks_status", value = "status_halted" } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
