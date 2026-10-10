-- Bind a homunculus to the field: a frail alchemical construct that fights for you until it falls or
-- its time runs out. One at a time, and it reserves a fifth of your maximum mana while it lives (see
-- data/items/ability/ability_summon_water_elemental.lua for how `reserve`, `scaling`, `duration` and
-- the one-at-a-time rule work). A cheap, expendable body whose Toxic Blow leaves foes Poisoned --
-- summon it into a crowd and let the rot do the work.
return {
    name = "Summon Homunculus",
    description = "Summons a frail homunculus. One at a time; reserves a fifth of your max mana.",
    flavor = "Cheap, expendable, and rotting the entire time. The Crucible built it that way deliberately.",
    sprite = "assets/items/ability_summon_homunculus.png",
    type = "ability",
    tags = { "summon", "poison" },
    class = "alchemist",
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
        reserve = { stat = "mana", percent = 0.2 },
        effect = function(fx)
            fx.summon("character_homunculus", fx.tx, fx.ty, {
                scaling = { health = 1, damage = 0.5 },
                amount = 8 + fx.level, -- base 8, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
