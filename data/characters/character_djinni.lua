-- THE DJINNI: the air djinn of Pride's spire, rung 1 (reviewed 2026-09-30, "Pride's Bestiary").
--
-- A mage with no master and no weapon. Its spell is the gale (Djinni's Breath): every body in a line is pushed 2
-- tiles, which turns a doorway a company has backed it into into a doorway the company has been blown back out
-- of. Will Not Stoop, like every djinn (the race's grant): a foe beside it when its turn opens and it blinks clear,
-- and a djinni boxed into a room's corner is Shamed and does nothing at all.
--
-- `skirmish`: it keeps its distance, which is what a caster with a range-1 lane spell and a blink at its back
-- does anyway. It drops its own gale.
return {
    name = "Djinni",
    race = "djinn",
    tier = 2,
    sprite = "assets/chars/djinni.png",
    archetype = "skirmish",
    unarmed = false, -- it casts; it never swings (Will Not Stoop)
    stats = {
        health = 42, mana = 40, stamina = 10,
        staminaRegen = 2, manaRegen = 4,
        damage = 0, magicDamage = 10,
        defense = 3, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 4, luck = 5,
    },
    --   Moving air: an arrow is blown wide, but a hammer drives it out of the room. Frost stills it.
    resist = { wind = 3, pierce = 2, impact = -2, ice = -3 },
    startingItems = {
        "ability_djinnis_breath", false, false,
        false,                    false, false,
        false,                    false, false,
    },
    drops = { "ability_djinnis_breath" },
    defaultAction = "ability_djinnis_breath",
    ai = {
        { priority = "high", act = "cast", item = "ability_djinnis_breath" },
    },
}
