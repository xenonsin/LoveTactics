-- A raised corpse, reached only through Raise Dead (data/items/ability/ability_raise_dead.lua). Slow
-- and witless -- it fights on your side but takes its own turns (AI-run) -- yet tough and strong, a
-- shambling wall of dead flesh. It carries Rotting Claws and no mana. See fire_elemental.lua for shape.
return {
    name = "Zombie",
    sprite = "assets/chars/zombie.png",
    stats = {
        health = 34, mana = 0, stamina = 50,
        staminaRegen = 1,
        damage = 9, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 3, -- shambling
        speed = 2,
    },
    startingItems = { "weapon_rotting_claws" },
}
