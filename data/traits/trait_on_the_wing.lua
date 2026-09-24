-- ON THE WING: the Griffin's flight, and Slay the Spire's Byrd by way of review (2026-09-23, "The Sated and
-- the Flight", round two, among five griffin candidates drawn from other games).
--
--   it opens with three stacks of status_on_the_wing: every blow that reaches it is halved
--   each blow strips a stack
--   the last one brings it down: Stunned, and Grounded for two turns, taking every blow whole
--   then it takes wing again with three (status_grounded's onExpire)
--
-- So the grounding window is something the company plays for and then earns again, and many light hits
-- earn it sooner than one heavy one. `notAReaction`: a stunned griffin is still knocked out of the air.
local Status = require("models.status")

return {
    name = "On the Wing",
    description = "Flies with three stacks, halving every blow. Each blow strips one; the last grounds it and inflicts Stun.",
    notAReaction = true,
    onCombatStart = function(ctx)
        Status.apply(ctx.combat, ctx.unit, "status_on_the_wing", { magnitude = 3 })
    end,
    onDamaged = function(ctx)
        local u = ctx.unit
        if not Status.has(u, "status_on_the_wing") then return end
        Status.spendStacks(ctx.combat, u, "status_on_the_wing", 1)
        if Status.has(u, "status_on_the_wing") then return end
        ctx.log("action", string.format("%s is knocked out of the air!", (u.char and u.char.name) or "It"), u)
        Status.apply(ctx.combat, u, "status_grounded")
        Status.apply(ctx.combat, u, "status_stun")
    end,
}
