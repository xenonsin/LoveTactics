-- Arcane Cleave: the fighter half of the Battlemage (fighter x mage). A single swing that carries a
-- spell's element: it routes as MAGICAL damage (through magicDefense, not armour) and sets the target
-- alight (data/status/status_burn.lua). Steel and sorcery in one motion -- the whole point of a
-- Battlemage, paid for in stamina so a sword-and-spell brawler is never out of fuel.
return {
    name = "Arcane Cleave",
    description = "A melee strike that lands as magical damage and sets the target Burning.",
    flavor = "The Arcanum would call it inelegant. The Arcanum has never been hit by it.",
    sprite = "assets/items/ability_arcane_cleave.png",
    type = "ability",
    tags = { "magical", "fire" }, -- magical: routes through magicDefense; fire: the element it carries
    class = "fighter",
    discipline = "battlemage", -- fighter x mage; the Spellstrike mechanic's first stock
    price = 280,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_burn")
        end,
    },
}
