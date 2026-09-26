-- BLOOD FEUD: the mark the goblins hang over whoever last hit one of them (data/traits/trait_blood_feud.lua,
-- models/feud.lua). Reviewed 2026-09-26, approved as pitched.
--
-- It sits on the FOE, not on the goblins, because it is one body the whole warband is looking at: every
-- goblin of the marking side deals +2 to it (trait_blood_feud's damageBonusVs), and one that can reach it
-- this turn attacks nothing else (AI.preempt). `feudSide` is stamped on apply so the mark knows whose grudge
-- it is.
--
-- It moves rather than stacks: the next foe to hit a goblin takes it (Feud.mark clears the old one). It ends
-- when no goblin of its side is left standing to hold it (onTick), or runs out after about five turns
-- without a fresh blow to renew it.
return {
    name = "Blood Feud",
    abbr = "Feud",
    description = "Marked by the goblins: they deal 2 extra damage to it, and any that can reach it attacks nothing else.",
    color = { 0.760, 0.180, 0.150 }, -- badge tint (blood)
    duration = 25, -- ~five turns; every fresh blow on a goblin renews it
    debuff = true,
    onApply = function(ctx)
        if ctx.applier then ctx.status.feudSide = ctx.applier.side end
    end,
    onTick = function(ctx)
        local side = ctx.status.feudSide
        local Trait = require("models.trait")
        for _, u in ipairs((ctx.combat and ctx.combat.units) or {}) do
            if u.alive and u.side == side and Trait.flag(u, "bloodFeud") then return end
        end
        ctx.expire()
    end,
}
