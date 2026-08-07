-- A raised corpse, reached only through Raise Dead (data/items/ability/ability_raise_dead.lua). Slow
-- and witless -- it fights on your side but takes its own turns (AI-run) -- yet tough and strong, a
-- shambling wall of dead flesh. It carries Rotting Claws and no mana. See fire_elemental.lua for shape.
--
-- It is also GRAVE-COLD (data/items/utility/utility_grave_cold.lua): healing does not reach the dead,
-- so a heal aimed at it burns it for the whole amount instead. Worth knowing before you raise one --
-- it is a body that rots down on a timer and cannot be topped up, and a healing zone your line is
-- standing in will quietly eat it.
return {
    name = "Zombie",
    kind = "undead",
    tier = 1,
    sprite = "assets/chars/zombie.png",
    stats = {
        health = 24, mana = 0, stamina = 13,
        staminaRegen = 1,
        damage = 9, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 4, -- shambling
        speed = 2,
    },
    startingItems = { "weapon_rotting_claws", "utility_grave_cold" },
    -- Basic tactics (models/ai.lua): witless but not aimless -- the raised corpse shambles onto the foe
    -- closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
