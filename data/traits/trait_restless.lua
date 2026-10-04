-- RESTLESS: what Restless Mail carries (data/items/armor/armor_restless_mail.lua; "Sloth's Bestiary", slice G,
-- approved word for word). When you are put to Sleep, wake at once, and your next blow deals 50% more.
--
-- Answered on the status landing (onStatusApplied, which is deliberately not gated by hard control -- the sleep that
-- just landed is what shuts reflexes off). The sleep is taken straight back off, which hands back every tick of the
-- shove it took (status_sleep's onExpire); the blow is Empowered, the monk's stored strike, at half the bearer's
-- Damage -- spent on the first blow that draws blood.
return {
    name = "Restless",
    description = "When you are put to Sleep, wake at once, and your next blow deals 50% more.",
    onStatusApplied = function(ctx)
        if ctx.role ~= "recipient" or not (ctx.status and ctx.status.id == "status_sleep") then return end
        local u = ctx.unit
        if not u.alive then return end
        ctx.clearStatus(u, "status_sleep")
        local Combat = require("models.combat")
        local half = math.max(1, math.floor(Combat.flatStat(u, "damage") * 0.5))
        ctx.applyStatus(u, "status_empowered", { magnitude = half, applier = u })
        ctx.log("status", string.format("%s will not stay down.", (u.char and u.char.name) or "Unit"), u)
    end,
}
