-- IFRIT'S COAL: the rule on the Ifrit's drop (utility_ifrits_coal). Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- A SPELL is a magical item, so a fire wand counts and a fire-tipped arrow does not. The fire lands where the
-- spell was aimed: a bolt's target, or the centre of a blast. It rides onCast, so a spell that is thrown but
-- misses still leaves its ember -- the ground was the target too.
return {
    name = "Ifrit's Coal",
    description = "Your fire spells set the target's tile alight.",
    onCast = function(ctx)
        local item = ctx.item
        if not (item and ctx.tx and ctx.ty) then return end
        local fire, magical = false, false
        for _, t in ipairs(item.tags or {}) do
            if t == "fire" then fire = true elseif t == "magical" then magical = true end
        end
        if not (fire and magical) then return end
        require("models.hazard").place(ctx.combat, ctx.tx, ctx.ty, "hazard_fire",
            { amount = 4, duration = 10, side = ctx.unit and ctx.unit.side })
    end,
}
