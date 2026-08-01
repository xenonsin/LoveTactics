-- Kaen -- the Ninja exemplar (rogue x mage multiclass), the marquee fusion the codebase named years
-- before it could sell it. Shadowclone: blink between decoys, vanish from sight, strike from stealth.
-- Met as a boss. Home shelf is rogue; the mage half is the illusion-work. Kit from
-- data/disciplines/ninja.lua.
return {
    name = "Kaen",
    sprite = "assets/chars/kaen.png",
    boss = true,
    class = "rogue",
    -- Scatters clones, stays unseen, strikes and swaps out (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 96, mana = 40, stamina = 22,
        staminaRegen = 2,
        damage = 20, magicDamage = 10,
        defense = 8, magicDefense = 9,
        movement = 4,
        speed = 6,
    },
    startingItems = {
        "weapon_iron_dagger",  "ability_vanishing_strike", "ability_mirror_image",
        "ability_scatterlight", "ability_shadow_trade",    "utility_substitution",
        "armor_smoke_mantle",  "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_dagger",
    -- Strike the wounded from stealth, then vanish on the same blow.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_vanishing_strike", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
