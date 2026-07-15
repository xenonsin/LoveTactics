-- Banner Aura: the standing pulse a planted banner carries on ITSELF. Not a buff on a fighter but the
-- engine behind one -- at the top of each of the banner's own turns it sweeps the 3x3 square around it
-- and grants every ally standing there the status the banner was raised to spread. That status id is
-- stamped on the banner unit as `unit.bannerAura` by the summon effect (see
-- data/items/ability/ability_rally_banner.lua and its siblings), so ONE aura status serves every kind
-- of banner -- rally (Inspiration), sacred (Blessing), renewing (Regeneration) -- and a new banner
-- needs only a new ability file, never a new status.
--
-- This is the same "a status is the ticking EFFECT, driven by a turn hook" idiom as Regeneration or
-- Burn, pointed outward at neighbors instead of inward. The banner itself is a control-"none" summon
-- (it holds position and never acts), but Combat.startTurn still fires this hook before it passes.
--
-- Applied with a huge duration so it lasts as long as the banner does -- when the banner falls the
-- status goes with the unit, and the Inspiration it was refreshing on nearby allies wears off on its
-- own short timer a round or so later. `hideLog` so the banner's every pulse doesn't spam the log.
return {
    name = "Banner Aura",
    abbr = "Bnr",
    description = "Grants a status to allies in the 3x3 square around the banner each turn.",
    color = { 0.85, 0.75, 0.45 },
    duration = 9999, -- effectively "for as long as the banner stands"; the banner dies first
    debuff = false,  -- NOT a debuff: Cure must never strip a banner's own aura
    hideLog = true,  -- the pulse is silent; the granted status logs itself once when first gained
    onTurnStart = function(ctx)
        local id = ctx.unit.bannerAura
        if not id then return end
        -- The 3x3 square centered on the banner (corners included). unitsNear reads a Manhattan
        -- diamond, so walk the nine cells directly to catch the diagonals too.
        for dy = -1, 1 do
            for dx = -1, 1 do
                local u = ctx.unitAt(ctx.unit.x + dx, ctx.unit.y + dy)
                if u and u.alive and u.side == ctx.unit.side and u ~= ctx.unit then
                    ctx.applyStatus(u, id)
                end
            end
        end
    end,
}
