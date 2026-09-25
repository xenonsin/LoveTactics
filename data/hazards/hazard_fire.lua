-- Fire: a spreading blaze. A unit entering the flames catches Burn (data/status/burn.lua), which
-- then keeps searing it for a few turns even after it steps clear. The fire lingers for a duration,
-- creeps into orthogonally-adjacent burnable terrain (forest), and is doused instantly by any cast
-- carrying the "water" tag. Left behind across a Fireball's blast (data/items/ability/ability_fireball.lua).
return {
    name = "Fire",
    description = "Inflicts Burn on units that enter, and spreads into forest. Doused by water.",
    tags = { "fire" },
    duration = 15,            -- ticks the flames persist: ~3 turns at Status.TICKS_PER_TURN
    disposition = "hostile",  -- the enemy AI steps around it
    dousedByTags = { "water" },
    spread = { intoTag = "burnable" }, -- creeps into adjacent burnable tiles
    -- EMBERWALK (Avaritia, and the Emberwalk Greaves lifted off her): fire ground does not touch a body
    -- carrying the flag, and its planner walks through it as if it were floor.
    welcomes = function(unit)
        return unit ~= nil and require("models.trait").flag(unit, "emberwalk") ~= nil
    end,
    onEnter = function(ctx)
        if ctx.unit and require("models.trait").flag(ctx.unit, "emberwalk") then return end
        -- ctx.amount (the Fireball/Flask item's level-scaled burn) sets how hard the Burn sears; nil
        -- (an arena-authored blaze) falls back to Burn's own blueprint magnitude.
        ctx.applyStatus(ctx.unit, "status_burn", { magnitude = ctx.amount })
    end,
}
