-- MOULT: once, at half health, the Larder Mother sheds her skin. Every harmful status goes with it, she
-- steps aside onto the nearest open ground her body fits, and the skin stays where she stood -- a husk
-- (character_larder_husk) that blocks those tiles until somebody breaks it.
--
-- On the same beat as the egg sac's burst (ability_egg_sac's phases, also at half), so her half-health
-- turn reads as one event. A killing blow skips it -- onDamaged fires only for a bearer that survives.
-- No room to step aside: she still sheds, and leaves no husk.
local AT = 0.5

return {
    name = "Moult",
    description = "Once, at half health: sheds every harmful status and steps aside, leaving a husk behind.",
    onDamaged = function(ctx)
        if (ctx.trait.stacks or 0) > 0 then return end
        local unit = ctx.unit
        local hp = unit.char.stats.health
        if not (hp.max and hp.max > 0 and hp.current / hp.max <= AT) then return end
        ctx.trait.stacks = 1
        local Combat = require("models.combat")
        Combat.cleanse(ctx.combat, unit)
        local oldX, oldY = unit.x, unit.y
        local w, h = unit.w or 1, unit.h or 1
        local x, y = Combat.openBlockNear(ctx.combat, oldX, oldY, w, h,
            { ignore = unit, clearOf = { x = oldX, y = oldY, w = w, h = h } })
        if x then
            ctx.teleport(x, y)
            ctx.summon("character_larder_husk", oldX, oldY, { noClaim = true, control = "none", timeless = true })
        end
        ctx.log("action", string.format("%s sheds her skin.", (unit.char and unit.char.name) or "It"))
    end,
}
