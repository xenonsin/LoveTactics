-- VANGUARD, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_vanguard@<race>`; `race` names the first leaning race only so the
-- blueprint loads. Built on the generic knight (the root the exemplar walks): 15 / 4 magic.
--
-- WHAT IT DOES ON THE BOARD (Open the Line, Bottom of the Cup, The Shieldwall): Shieldbreak drives your
-- front body back two tiles and Sunders it, and the Breaker's Wedge Sunders whatever any of its shoves
-- moves; Pry Open is the cheaper Sunder for a foe it will not shove. The armour comes off ahead of the
-- duelist and the barbarian. No Stripped Plate (it would wear what it strips) and no Mailpiercer (a
-- floor-fifteen find that ignores armour outright): this is the body met as traffic, not the exemplar.
return {
    name = "Vanguard",
    race = "dwarf",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/vanguard.png",
    class = "knight",
    discipline = "vanguard",
    archetype = "aggressive",
    stats = {
        health = 70, mana = 15, stamina = 20,
        staminaRegen = 2,
        damage = 15, magicDamage = 4,
        defense = 11, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_iron_sword", "ability_shieldbreak", "ability_pry_open",
        "utility_breakers_wedge", "armor_chainmail",
    },
    defaultAction = "weapon_iron_sword",
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "ability_shieldbreak",
    -- Break the guard of whatever is beside it; pry at what it can reach otherwise.
    ai = {
        { priority = "high", act = "attack", item = "ability_shieldbreak", targetPref = "nearest",
          when = { subject = "any_foe", test = "within", value = 1 } },
        { priority = "normal", act = "attack", item = "ability_pry_open", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
