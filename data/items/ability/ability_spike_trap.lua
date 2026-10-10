-- An ability that lets its bearer summon a hidden spike trap on a nearby tile. Uses the tile-target
-- ability kind (target = "tile"): Combat.useItem allows any in-range cell and hands the clicked
-- coordinates to the effect as fx.tx / fx.ty, which fx.placeTrap turns into an owned trap.
return {
    name = "Spike Trap",
    description = "Places a hidden spike trap on a nearby tile.",
    flavor = "The Undercroft's idea of leaving a note.",
    sprite = "assets/items/ability_spike_trap.png",
    type = "ability",
    tags = { "trap", "utility" },
    class = "poacher", -- rogue x hunter; the rogue half of Snare-execute -- the trap that sets up the finish
    price = 345,
    unlockLevel = 6,
    activeAbility = {
        -- THE AI CAN LAY THIS NOW (2026-10-09): its mark is open ground, which the planner never offered a
        -- cast until `aiAims` names the cells worth trying (models/ai_aims.lua), and a plant that lands no
        -- entry the turn it is cast is credited through `aiPlants` (models/ai.lua). Before this, every
        -- body carrying it -- the trapper, the summoner, their exemplars -- held it and never once used it.
        aiAims = function(combat, unit) return require("models.ai_aims").besideFoes(combat, unit) end,
        aiPlants = true,
        target = "tile",
        range = 3,
        speed = 4,
        cost = { stat = "mana", amount = 8 },
        effect = function(fx)
            -- The forged trap bites harder: base 18 damage, +1 per upgrade level.
            fx.placeTrap(fx.tx, fx.ty, "spike_trap", { amount = 18 + fx.level })
        end,
    },
}
