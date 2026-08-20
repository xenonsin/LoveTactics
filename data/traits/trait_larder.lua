-- LARDER HOOK: what you are carrying above half is what you swing with.
--
--   baseline   a company opens a fight at full health, so this pays from the first exchange and thins
--              as the fight takes its toll. Real on its own, and honestly shaped: it is the reward for
--              being ahead.
--   synergy    the Maw of the Unfed heals its wearer on every blow LANDED (trait_ravenous), and every
--              point of that heal past full is currently thrown away. This is what the surplus is for.
--              Together the curve inverts -- the longer the trade runs the harder you hit -- which is
--              what Gula was, and what the Maw alone could never express.
--
-- Read at the moment of the swing (`onCast`) rather than banked, so it tracks the fight rather than a
-- high-water mark. Losing the health loses the damage, which is what stops it being a free ramp.
return {
    name = "Larder",
    description = "Increase damage by 1 per 6 health you hold above half.",
    share = 6, -- a point of damage per this much health above the halfway mark
    onCast = function(ctx)
        local hp = ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.health
        if not hp or (hp.max or 0) <= 0 then return end
        local over = (hp.current or 0) - (hp.max / 2)
        local want = over > 0 and math.floor(over / ctx.def.share) or 0
        local have = ctx.trait.applied or 0
        if want == have then return end
        ctx.addBonus("damage", want - have)
        ctx.trait.applied = want
    end,
}
