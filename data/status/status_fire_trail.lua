-- FIRE TRAIL: what an Ifrit's Flame leaves on the body it strikes (ability_ifrits_flame). Reviewed 2026-09-30
-- ("Pride's Bestiary"): the bolt "burns each tile the target is pushed or steps through".
--
-- Bleed's shape with fire's answer. It fires from `onEnterTile`, so a walk and a shove both pay and a blink pays
-- nothing (a blink crosses no ground): every tile entered catches Fire (hazard_fire) and the body catches Burn
-- from it, exactly as if it had walked into a blaze. Standing still costs nothing, which is the decision -- and
-- the Djinni's gale is what makes it nobody's decision to make.
--
-- A debuff, so a Cure lifts it; water does not, because the fire it lays is ordinary fire and a Marid's flood
-- already puts that out.
return {
    name = "Fire Trail",
    abbr = "Trail",
    description = "Fire Trail: every tile it is pushed or steps through catches Fire.",
    color = { 0.930, 0.420, 0.180 }, -- badge tint (live coal)
    fx = { field = true },
    duration = 10, -- two turns
    magnitude = 4, -- the Burn each tile lays
    debuff = true,
    onEnterTile = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive and ctx.combat) then return end
        require("models.hazard").place(ctx.combat, unit.x, unit.y, "hazard_fire",
            { amount = ctx.magnitude, duration = 10 })
        if require("models.trait").flag(unit, "emberwalk") then return end
        ctx.applyStatus(unit, "status_burn", { magnitude = ctx.magnitude })
    end,
}
