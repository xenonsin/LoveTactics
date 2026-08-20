-- BEGGAR'S DUE: a body holding nothing back has nothing to answer with.
--
--   baseline   one pool empty -- no stamina, or no mana -- and the blow lands heavier. That happens in
--              any long fight to any caster, so the piece pays without help.
--   synergy    the Reliquary of the Unbidden drains BOTH pools off its target on every cast
--              (trait_rapture), so a second swing at the same body finds it empty twice over and this
--              doubles. The Reliquary strips a foe and has no way to profit from having done it; this
--              is the profit.
--
-- Checked on the target of the swing, at the swing. Nothing is banked: a foe that gets its wind back is
-- a foe that stops being easy, which is the counterplay and should stay available.
return {
    name = "Beggar's Due",
    description = "Increase damage by 4 if the target's stamina is 0. Increase damage by 4 if the target's mana is 0.",
    bonus = 4, -- damage per empty pool
    onCast = function(ctx)
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        local stats = target.char and target.char.stats
        if not stats then return end

        local empty = 0
        for _, pool in ipairs({ "stamina", "mana" }) do
            local p = stats[pool]
            -- A pool the body does not HAVE is not a pool it has spent. A knight with no mana bar has
            -- held nothing back, and counting that would make every martial body permanently robbed.
            if p and (p.max or 0) > 0 and (p.current or 0) <= 0 then empty = empty + 1 end
        end
        if empty == 0 then return end
        ctx.damage(target, ctx.def.bonus * empty)
    end,
}
