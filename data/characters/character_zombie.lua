-- A raised corpse, reached only through Raise Dead (data/items/ability/ability_raise_dead.lua). Slow
-- and witless -- it fights on your side but takes its own turns (AI-run) -- yet tough and strong, a
-- shambling wall of dead flesh. It carries Rotting Claws and no mana. See fire_elemental.lua for shape.
return {
    name = "Zombie",
    sprite = "assets/chars/zombie.png",
    stats = {
        health = 24, mana = 0, stamina = 50,
        staminaRegen = 1,
        damage = 9, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 3, -- shambling
        speed = 2,
    },
    startingItems = { "weapon_rotting_claws" },
    -- Basic tactics (models/ai.lua): witless but not aimless -- the raised corpse shambles onto the foe
    -- closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
