-- Poacher exemplar (rogue x hunter multiclass). Snare-execute: traps set up the blink-kill, with a
-- bonus against the Rooted. Met as a bounty-jumping trapper, a recruit. Home shelf is rogue
-- (Poacher's Kris). Kit from data/disciplines/poacher.lua.
return {
    name = "Poacher",
    sprite = "assets/chars/poacher.png",
    class = "rogue",
    -- Roots them in a trap first, then cuts the throat; holds ground to let them step wrong (defensive).
    archetype = "defensive",
    stats = {
        health = 64, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 16, magicDamage = 4,
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "weapon_poachers_kris", "ability_bolas",         "ability_throatcut",
        "utility_quarrys_due",  "utility_the_long_wait", "armor_leather_armor",
        "consumable_healing_potion", false,             false,
    },
    defaultAction = "weapon_poachers_kris",
    -- 1. Net an unrooted foe. 2. Once rooted, execute it -- the bonus lands on the Rooted.
    ai = {
        { priority = "high", act = "cast", item = "ability_bolas",
          when = { subject = "any_foe", test = "lacks_status", value = "status_root" } },
        { priority = "urgent", act = "attack", item = "ability_throatcut", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "has_status", value = "status_root" } },
    },
}
