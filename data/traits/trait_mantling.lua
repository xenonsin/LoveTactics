-- MANTLING: what makes a hawk let go. The grip is taken by the Raking Talons
-- (data/items/weapon/weapon_raking_talons.lua) on a blow that leaves its quarry below half, and it lives on
-- the prey's status_mantled, whose onApply and onExpire tie and untie both bodies. Reviewed 2026-09-23:
-- "Stoop and mantling is cool", and on Mantling itself, "have it root".
--
-- This trait is the hawk's end of it. The grip breaks when:
--   * anything hits the hawk -- the counterplay; it cannot dodge while it eats (status_mantling)
--   * the hawk falls
--   * the prey falls (its statuses go with it, and status_mantled's onExpire unties the hawk)
--
-- `notAReaction`: a stunned hawk still loses its grip to a blow. Letting go is not an answer it throws.
local Status = require("models.status")

local function release(ctx)
    local prey = ctx.unit.mantlingPrey
    if prey then Status.remove(ctx.combat, prey, "status_mantled") end
    ctx.unit.mantlingPrey = nil
    Status.remove(ctx.combat, ctx.unit, "status_mantling")
end

return {
    name = "Mantling",
    description = "A foe it leaves below half is held and fed on each turn, until the hawk is struck.",
    notAReaction = true,
    onDamaged = function(ctx)
        if not ctx.unit.mantlingPrey then return end
        release(ctx)
        ctx.log("action", string.format("%s is struck off its prey.",
            (ctx.unit.char and ctx.unit.char.name) or "The hawk"), ctx.unit)
    end,
    onDeath = function(ctx)
        if ctx.unit.mantlingPrey then release(ctx) end
    end,
    -- A corpse may keep its badges, so the grip is let go here rather than trusted to the prey's status
    -- going with it. `mantledBy` stays on the body (status_mantled's onExpire leaves a fallen prey marked).
    onAnyDeath = function(ctx)
        if ctx.fallen and ctx.fallen == ctx.unit.mantlingPrey then release(ctx) end
    end,
}
