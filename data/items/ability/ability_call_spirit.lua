-- Call Spirit: the mage half of the Shaman (hunter x mage). Binds a wind spirit to a tile -- an
-- elemental body that fights on its own until the binding lapses. Reserves a fifth of the caster's max
-- mana for as long as it stands, the reserve-summon economy the Arcanum uses for its elemental court
-- (docs/classes.md), here carried onto the hunter's shelf: the Lodge calls the spirits of the field,
-- the Arcanum lends the mana that holds them.
return {
    name = "Call Spirit",
    description = "Summons a wind spirit that fights on its own. Reserves a fifth of your max mana.",
    flavor = "The Arcanum summons. The Lodge asks. The wind, it turns out, prefers being asked.",
    sprite = "assets/items/ability_call_spirit.png",
    type = "ability",
    tags = { "summon" },
    class = "shaman", -- hunter x mage; the Spirit-totems mechanic's first stock
    price = 650,
    unlockLevel = 13,
    activeAbility = {
        -- THE RIFT'S ADVENTURERS, SLICE C (2026-10-09): what this leaves is on EMPTY ground, so the planner
        -- aims it at open cells (models/ai_aims.lua) and credits the plant (models/ai.lua, `aiPlants`).
        -- Without both, no AI body could ever cast it.
        aiAims = function(combat, unit) return require("models.ai_aims").beside(combat, unit) end,
        aiPlants = true,
        target = "tile",
        range = 2,
        speed = 5,
        reserve = { stat = "mana", percent = 0.2 },
        effect = function(fx)
            fx.summon("character_wind_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                amount = 10 + fx.level,
                duration = 22,
            })
        end,
    },
}
