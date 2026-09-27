-- CALL THE BLOOD: the Sire's (Wrath's vampires, 2026-09-26, round 2). Every three turns, every bleeding foe within 5
-- is pulled 2 tiles toward the Sire (Combat.pullBy, no line of sight: it reaches for the blood). Forced movement is
-- movement, so each tile hauled is a Bleed tick -- and Running Feeds It hands every tick to whoever cut them.
return {
    name = "Call the Blood",
    description = "Every bleeding foe within 5 is pulled 2 tiles toward you.",
    flavor = "Every open wound on the field leans toward it, and the bodies wearing them follow.",
    sprite = "assets/items/ability_call_the_blood.png",
    type = "ability",
    tags = { "natural", "blood" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        cooldown = 15, -- three turns
        support = true,
        ai = { priority = "high", act = "cast", label = "the blood answers",
               whenFn = function(ctx)
                   local Status = require("models.status")
                   local Combat = require("models.combat")
                   for _, u in ipairs(ctx.combat.units or {}) do
                       if u.alive and u.side ~= ctx.unit.side and Status.has(u, "status_bleed")
                           and Combat.unitGap(ctx.unit, u) <= 5 and Combat.unitGap(ctx.unit, u) > 1 then
                           return true
                       end
                   end
                   return false
               end },
        effect = function(fx)
            local user = fx.user
            for _, u in ipairs(fx.unitsNear(user.x, user.y, 5)) do
                if u.side ~= user.side and fx.hasStatus(u, "status_bleed") then fx.pullBy(u, 2) end
            end
        end,
    },
}
