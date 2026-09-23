-- Spore Cloud: the smoke a Thurifer swings, and the censer family's third voice from the Cathedral's
-- own floor. Incense blesses the ground it walks (hazard_incense), Choking Fumes poisons it
-- (hazard_choking); this one takes the will to strike out of whoever breathes it.
--
-- SIDED TO THE BEARER, like the fumes, so the mushroom folk breathe their own spores freely and a
-- company that carries the censer out of the Ossuary does the same. What it lays is Swoon
-- (data/status/status_swoon.lua), and ZONE-BOUND like every status a ground grants: step out of the
-- smoke and the swoon ends with it. That is the counterplay and it is range -- a cloud that walks is a
-- cloud you shoot into rather than stand in.
return {
    name = "Spore Cloud",
    description = "Inflicts Swoon on foes in it.",
    tags = { "nature", "poison" },
    duration = 12,           -- as Incense: renewed each beat by the censer, and gone within a turn without one
    disposition = "hostile", -- the enemy AI steps around a foe's cloud, which is itself a way to push a line
    onEnter = function(ctx)
        if ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_swoon")
    end,
}
