-- BURSTING: an asura whose chi has filled (models/asura.lua). Its next action is not chosen -- it throws its
-- Burst, every point of chi in one blow, at the NEAREST FOE (AI.preempt -> Asura.plan). The Burst spends the
-- pool, and the pool reading below full is what lifts this (Asura.checkBurst).
--
-- ON A COMPANY BODY THE GAME TAKES THE TURN, the way Bloodlust does: a monk wearing the Broken Vow has its
-- control stashed and handed to the AI until the Burst is thrown. Not a debuff -- nothing lifts a full pool
-- but spending it, and a Cure that "cured" it would hand the monk back a free, chosen Asura Strike.
return {
    name = "Bursting",
    abbr = "Brst",
    description = "Bursting: chi is full. The next action is a Burst at the nearest foe.",
    color = { 0.890, 0.420, 0.160 }, -- badge tint (the halo's orange)
    duration = math.huge,
    hideDuration = true,
    onApply = function(ctx)
        local u = ctx.unit
        if u.side ~= "party" then return end
        if u._burstingControl == nil then u._burstingControl = u.control or false end
        u.control = "ai"
    end,
    onExpire = function(ctx)
        local u = ctx.unit
        if u._burstingControl ~= nil then
            u.control = u._burstingControl or nil
            u._burstingControl = nil
        end
    end,
}
