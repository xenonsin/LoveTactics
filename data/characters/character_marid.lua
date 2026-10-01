-- THE MARID: the water djinn of Pride's spire, rung 1 and tier 3 (reviewed 2026-09-30, "Pride's Bestiary"): the
-- eldest and proudest of the three, and the one a company must reach first.
--
-- Its spell (Marid's Tide) floods a 3x3 square: every body inside is Wet, and the Marid heals for every Wet foe
-- on the board. So a company that soaks is a company it drinks from -- and a company that stays out of its water
-- is one it cannot mend from. Will Not Stoop, like every djinn: the reach that would kill it fastest is the reach
-- it will not allow.
--
-- It drops its tide, on the druid's shelf.
return {
    name = "Marid",
    race = "djinn",
    tier = 3,
    sprite = "assets/chars/marid.png",
    archetype = "skirmish",
    unarmed = false, -- it casts; it never swings (Will Not Stoop)
    stats = {
        health = 92, mana = 54, stamina = 12,
        staminaRegen = 2, manaRegen = 5,
        damage = 0, magicDamage = 12,
        defense = 4, magicDefense = 8,
        movement = 4,
        speed = 4,
        skill = 5, luck = 5,
    },
    --   A body of water: a club splashes through it and fire hisses out on it, but an arrow or a blade holds a
    --   line, and lightning finds every inch of it.
    resist = { water = 4, fire = 2, impact = 2, pierce = -1, slash = -1, lightning = -6 },
    startingItems = {
        "ability_marids_flood", false, false,
        false,                 false, false,
        false,                 false, false,
    },
    drops = { "ability_marids_tide" },
    defaultAction = "ability_marids_flood",
    ai = {
        { priority = "high", act = "cast", item = "ability_marids_flood" },
    },
}
