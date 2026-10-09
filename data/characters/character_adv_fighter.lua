-- THE ADVENTURER FIGHTER ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: the fight fields it as `character_adv_fighter@<race>`, and `race` below is only the
-- class's first leaning race, so the bare blueprint loads. It is never fielded as itself.
--
-- Chaff (tier 1), because a root is the body a floor-one party is made of: the generic Fighter's kit and
-- magic pair, its physical line cut down into the rung. What it does in a party is the template's thesis
-- -- Rend opens a wound, the axe sweeps the front into it -- with the Reckless Cuirass as the price Fire
-- and Steel names: every trade costs him three more than it costs you, so letting him come is the answer.
return {
    name = "Fighter",
    race = "orc",
    tier = 1,
    adventurer = true,
    class = "fighter",
    sprite = "assets/chars/saber.png",
    archetype = "aggressive",
    stats = {
        health = 30, mana = 5, stamina = 25,
        staminaRegen = 2,
        damage = 10, magicDamage = 3,
        defense = 4, magicDefense = 3,
        movement = 4,
        speed = 3,
        skill = 5, luck = 3,
    },
    -- Clear Out sits beside the axe it needs (requiresAdjacent).
    startingItems = {
        "weapon_iron_axe", "ability_clear_out", "ability_rend",
        "armor_reckless_cuirass", "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
    signatureAbility = "ability_rend",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        -- Open the wound first, then swing into it.
        { priority = "normal", act = "attack", item = "ability_rend",
          when = { subject = "nearest_foe", test = "lacks_status", value = "status_vulnerable_slash" } },
    },
}
