-- Rask, the Poacher the Hiring Hall offers. A version of the poacher exemplar
-- (data/characters/character_poacher.lua, the bounty-jumping trapper), which stays put.
--
-- Quarry's End (data/items/utility/utility_quarrys_end.lua) is the SETUP rather than the kill: it Roots
-- and Marks the whole field, and then Throatcut, Poacher's Kris and The Long Wait all go live at once.
-- An earlier draft executed instead, which was Throatcut with a bigger footprint.
return {
    name = "Rask",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/rask.png",
    class = "rogue",
    discipline = "poacher",
    archetype = "defensive",
    stats = {
        health = 86, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 7, magicDefense = 5,
        movement = 4,
        speed = 5,
    },
    startingItems = {
        "weapon_poachers_kris", "ability_bolas",       "ability_spike_trap",
        "ability_throatcut",    "utility_quarrys_end", "utility_quarrys_due",
        "utility_the_long_wait", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_poachers_kris",
    signatureWeapon  = "weapon_poachers_kris",
    signatureAbility = "utility_quarrys_end",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
