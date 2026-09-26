-- SEEING RED: the Red Mist's grip (hazard_red_mist), and a riderless wolf's (trait_two_in_one). Reviewed
-- 2026-09-26, round 2: "lose control of them and they use any action towards any target".
--
-- The body does not choose its turn. AI.preempt rolls a random action from its own kit and a random target in
-- range -- friend, foe or itself -- and Combat.useItem waives its side check for it, so a blade can land on a
-- friend and a heal on a foe. The Blind of the round-1 pitch was cut: the random pick replaces it.
--
-- ON A COMPANY BODY THE GAME TAKES THE TURN, the way Charm does: control is stashed and handed to the AI for
-- as long as this lasts, and handed back when it ends.
return {
    name = "Seeing Red",
    abbr = "Red",
    description = "Lost to rage: uses a random action on a random target, friend or foe.",
    color = { 0.800, 0.160, 0.160 }, -- badge tint (red mist)
    duration = 10,
    debuff = true,
    onApply = function(ctx)
        local u = ctx.unit
        if u._seeRedControl == nil then u._seeRedControl = u.control or false end
        u.control = "ai"
    end,
    onExpire = function(ctx)
        local u = ctx.unit
        if u._seeRedControl ~= nil then
            u.control = u._seeRedControl or nil
            u._seeRedControl = nil
        end
    end,
}
