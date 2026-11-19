-- CINDER TRAIL: Wrath's slime rule (the creature identity pass, 2026-11-19). It replaced Boil Over, which
-- taught "every hit charges it, so burst it or leave it alone" -- the Asura line's lesson, printed on a fifth
-- and sixth body. A slime asks a company what it BROUGHT; this one also asks where it is allowed to walk.
--
-- The bearer wears Fire Trail for the whole fight (status_fire_trail, the Ifrit's mark on a foe, here worn on
-- purpose): every tile it steps through or is shoved through catches Fire, and the fire does not touch it
-- (`emberwalk`, the flag hazard_fire already reads). So a cinder slime walking at the company paints a line of
-- burning ground behind it, and the counter is on the board: meet it before it crosses your line, pin it, or
-- bring water -- which douses the trail and which the body is soft to.
--
-- Put back at the top of every turn as well as at the bell, because the Caldera King's pieces arrive mid-fight
-- and never hear an opener (trait_split), and because a Cure from somewhere could lift the badge.
local function light(ctx)
    local u = ctx.unit
    if not (u and u.alive) then return end
    if require("models.status").has(u, "status_fire_trail") then return end
    ctx.applyStatus(u, "status_fire_trail", { duration = math.huge, applier = u })
end

return {
    name = "Cinder Trail",
    grade = 1.0, -- weighed beside the rule (Grade.traitValue reads it): a fire trail it walks, which it cannot itself be hurt by
    description = "Every tile it steps through catches Fire. Fire on the ground does not harm it.",
    emberwalk = true,
    onCombatStart = light,
    onTurnStart = light,
}
