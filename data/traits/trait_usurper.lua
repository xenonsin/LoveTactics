-- USURPER: the Hollow Crown's want for what others hold, carried out (data/items/utility/utility_usurper.lua; slice D).
-- When a foe carrying boons falls within 3 of the bearer, every boon it carried passes to the bearer, at the length
-- it had left.
--
-- A BOON is what Combat.dispellableOn calls a blessing: not a debuff, not the engine's own bookkeeping (`hideLog`),
-- not what a body IS (`undispellable`). Read off the fallen body's badges directly, since dispellableOn asks only the
-- living. A boon with no real clock (a stance laid for the whole fight) is left with its owner, Begrudge's rule.
return {
    name = "Usurper",
    description = "When a foe with boons falls within 3 of you, its boons pass to you.",
    reach = 3,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen) or fallen.side == u.side then return end
        if require("models.combat").unitGap(u, fallen) > ctx.param("reach", 3) then return end
        local taken = 0
        for _, s in ipairs(fallen.statuses or {}) do
            local def = s.def
            if def and not def.debuff and not def.hideLog and not def.undispellable
                and (s.remaining or 0) > 0 and (s.remaining or 0) <= 1e6 then
                if ctx.applyStatus(u, s.id, { duration = s.remaining, magnitude = s.magnitude, applier = u, echoed = true }) then
                    taken = taken + 1
                end
            end
        end
        if taken > 0 then
            ctx.log("status", string.format("%s takes what %s held.", (u.char and u.char.name) or "It",
                (fallen.char and fallen.char.name) or "the fallen"))
        end
    end,
}
