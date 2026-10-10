-- Bind a wind elemental to the field. See ability_summon_fire_elemental.lua for how the reservation,
-- scaling, duration and one-at-a-time rule work. A blindingly fast scout -- frail, but everywhere.
return {
    name = "Summon Wind Elemental",
    description = "Summons a wind elemental. One at a time; reserves a quarter of your max mana.",
    flavor = "Frail, and everywhere. The Arcanum has never once persuaded one to sit still.",
    sprite = "assets/items/ability_summon_wind_elemental.png",
    type = "ability",
    tags = { "summon", "wind" },
    class = "summoner", -- deeper cut of the shelf: buyable only once the summoner gate is cleared
    price = 695,
    unlockLevel = 14,
    activeAbility = {
        -- THE AI CAN LAY THIS NOW (2026-10-09): its mark is open ground, which the planner never offered a
        -- cast until `aiAims` names the cells worth trying (models/ai_aims.lua), and a plant that lands no
        -- entry the turn it is cast is credited through `aiPlants` (models/ai.lua). Before this, every
        -- body carrying it -- the trapper, the summoner, their exemplars -- held it and never once used it.
        aiAims = function(combat, unit) return require("models.ai_aims").beside(combat, unit) end,
        aiPlants = true,
        target = "tile",
        range = 2,
        speed = 6,
        reserve = { stat = "mana", percent = 0.25 },
        effect = function(fx)
            fx.summon("character_wind_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.4 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
