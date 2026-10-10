-- Bind a lightning elemental to the field. See ability_summon_fire_elemental.lua for how the
-- reservation, scaling, duration and one-at-a-time rule work. A frail but hard-hitting glass cannon.
return {
    name = "Summon Lightning Elemental",
    description = "Summons a lightning elemental. One at a time; reserves a quarter of your max mana.",
    flavor = "A glass cannon with a temper. It will not be alive long enough to regret it.",
    sprite = "assets/items/ability_summon_lightning_elemental.png",
    type = "ability",
    tags = { "summon", "lightning" },
    class = "summoner", -- deeper cut of the shelf: buyable only once the summoner gate is cleared
    price = 565,
    unlockLevel = 11,
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
            fx.summon("character_lightning_elemental", fx.tx, fx.ty, {
                scaling = { health = 1, magicDamage = 0.5 },
                amount = 12 + fx.level, -- base 12, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
