-- THE STILL POOL (utility_still_pool): the Water Mirror's rule. At the opening bell it locks its own face (a pool
-- wears none: it makes them, so the race's Reshape stands aside) and stands an exact copy of every body in the
-- company around itself (Masks.mirrorCompany). The ward -- nothing while a copy stands, and a copy untouched by its
-- own original -- is answered in Status.immuneToDamage (Masks.ward), so the forecast says it too.
--
-- This organ sits ahead of the race's grant in the grid, so it fires first: the empty hand it sets is what tells
-- A Thousand Faces not to deal one.
return {
    name = "The Still Pool",
    description = "At the start of the fight, copy every foe. Cannot be moved, or harmed while a copy stands.",
    notAReaction = true,
    unmoved = true,
    stillPool = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        u.faceLocked, u.faceHand = true, {}
        local copies = require("models.masks").mirrorCompany(ctx.combat, u)
        if #copies > 0 then
            ctx.log("system", string.format("%s shows the company itself: %d copies rise out of the water.",
                (u.char and u.char.name) or "The Water Mirror", #copies))
        end
    end,
}
