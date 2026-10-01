-- THE IFRIT: the fire djinn of Pride's spire, rung 1 (reviewed 2026-09-30, "Pride's Bestiary").
--
-- Its bolt (Ifrit's Flame) sets the struck tile alight and puts the target on a Fire Trail: every tile it is
-- pushed or steps through for two turns catches fire under it. Alone it asks a company to stand still; beside a
-- Djinni, whose gale pushes everyone in a line, it is not a request. Will Not Stoop, like every djinn.
--
-- It drops the coal that lights its spells (Ifrit's Coal), on the elementalist's shelf.
return {
    name = "Ifrit",
    race = "djinn",
    tier = 2,
    sprite = "assets/chars/ifrit.png",
    archetype = "skirmish",
    unarmed = false, -- it casts; it never swings (Will Not Stoop)
    stats = {
        health = 46, mana = 40, stamina = 10,
        staminaRegen = 2, manaRegen = 4,
        damage = 0, magicDamage = 11,
        defense = 3, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 4, luck = 4,
    },
    --   Smokeless fire: a blade passes through and an arrow finds nothing, but a club scatters it. Water puts
    --   it out.
    resist = { fire = 3, slash = 1, pierce = 1, impact = -2, water = -4 },
    startingItems = {
        "ability_ifrits_flame", false, false,
        false,                  false, false,
        false,                  false, false,
    },
    drops = { "utility_ifrits_coal" },
    defaultAction = "ability_ifrits_flame",
    ai = {
        { priority = "high", act = "cast", item = "ability_ifrits_flame" },
    },
}
