-- MIRRORED (utility_mirrored): the Mirror-Knight's rule. Both existing mirrors go up at the opening bell and at the
-- top of each of its turns; `mirrorOnce` makes the first blow either one turns take both down (Combat's
-- tryWardSpell reads it), so it answers one single-target attack a round and no more.
--
-- The window is a little over a turn, so a mirror nobody struck still stands when the next turn puts it back up.
local WINDOW = 15

local function raise(ctx)
    local u = ctx.unit
    if not (u and u.alive and ctx.combat) then return end
    local w = ctx.param("window", WINDOW)
    ctx.applyStatus(u, "status_reflect_physical", { applier = u, duration = w })
    ctx.applyStatus(u, "status_reflect_magic", { applier = u, duration = w })
end

return {
    name = "Mirrored",
    description = "At the start of your turn, gain Reflect Steel and Reflect Magic. The first blow they turn ends both.",
    notAReaction = true,
    mirrorOnce = true,
    window = WINDOW,
    onCombatStart = raise,
    onTurnStart = raise,
}
