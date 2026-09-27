-- THE BLOOD BASIN: the Blood Countess's bath (models/basin.lua). A 2x2 object set in the middle of the board as the
-- fight opens; every point of Bleed damage taken anywhere fills it, and its badge prints the count. Full, it draws
-- the Countess's bath. It takes no turns (`timeless`) and does not grow with the fight (`scaling = false`), so
-- "break the basin" is the same answer on every floor: sturdy enough to cost a turn or two of blows, never more.
-- With nobody left on its side to bathe in it, it goes with them (trait_blood_basin).
return {
    name = "Blood Basin",
    race = "object",
    tier = 0,
    timeless = true,
    scaling = false,
    sprite = "assets/chars/blood_basin.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 70, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 6, magicDefense = 6,
        movement = 0, -- stone: it does not move
        speed = 0,    -- it takes no turns
        skill = 0, luck = 0,
    },
    startingItems = { "utility_blood_basin" },
}
