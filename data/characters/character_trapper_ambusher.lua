-- Trapper exemplar (hunter subclass). Hidden traps: pre-placed tile triggers that fire on enemy entry.
-- Met as a woodland ambusher, a boss. Kit from data/disciplines/trapper.lua.
--
-- NOTE the id: `character_trapper` already belongs to the Colosseum debut-bout spotter
-- (data/characters/character_trapper.lua -- a deliberately soft body tuned for that one fight and
-- asserted by tests/saber_debut_spec.lua). This is the discipline EXEMPLAR, a distinct body with the
-- full trap kit; data/disciplines/trapper.lua's `exemplar` points here.
return {
    name = "Ambusher",
    sprite = "assets/chars/bandit.png",
    boss = true,
    class = "hunter",
    -- Seeds the ground, then holds until they step wrong (models/ai.lua `defensive`).
    archetype = "defensive",
    stats = {
        health = 100, mana = 10, stamina = 22,
        staminaRegen = 2,
        damage = 16, magicDamage = 4,
        defense = 9, magicDefense = 6,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_iron_longbow", "ability_bear_trap",   "ability_snare_stake",
        "ability_blightstake", "consumable_snare_stake", "utility_caltrop_greaves",
        "utility_trap_sense",  "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_longbow",
    -- Stake the ground when a foe approaches; otherwise plink from range.
    ai = {
        { priority = "high", act = "cast", item = "ability_snare_stake",
          when = { subject = "any_foe", test = "within", value = 4 } },
        { priority = "normal", act = "attack", item = "weapon_iron_longbow", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
