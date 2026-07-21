-- One of Acedia's company: a knight who walked out of the gate with her and took the terms
-- (docs/story.md). They are not corrupted victims -- corruption was the FEE, and every one of them
-- agreed to it. Still a disciplined company, still in the Bastion's forms, in something else's
-- service. They kept every part of the oath except the part that cost anything.
--
-- The spear is the whole tactical job. Acedia's rule pins the party into a huddle
-- (data/traits/trait_unrelieved.lua) and a spear skewers two tiles in a line, so the formation her
-- oath forces is the formation these punish. She makes the shape; they charge for it.
return {
    name = "Forsworn Knight",
    sprite = "assets/chars/forsworn_knight.png",
    class = "knight",
    stats = {
        health = 62, mana = 0, stamina = 50,
        staminaRegen = 2,
        damage = 15, magicDamage = 0,
        defense = 14, magicDefense = 6,
        movement = 3,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_spear", "armor_chainmail", false,
        false,               false,             false,
        false,               false,             false,
    },
    defaultAction = "weapon_iron_spear",
}
