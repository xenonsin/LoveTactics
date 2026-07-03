return {
    name = "Knight",
    sprite = "assets/chars/knight.png",
    stats = {
        health = 100, mana = 20, stamina = 60, -- resource stats
        damage = 14, magicDamage = 4,          -- flat stats
        defense = 10, magicDefense = 6,
        movement = 3, -- number of spaces this character can move
    },
    startingItems = { "iron_sword", "healing_potion" }, -- item ids
}
