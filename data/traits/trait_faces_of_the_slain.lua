-- FACES OF THE SLAIN: what Borrowed Face (ninja) and Hall of Faces (assassin) are filled by -- the Faceless trick
-- lent to a person (reviewed 2026-10-01..03, "Envy's Bestiary", round 2). Each foe the bearer kills leaves its
-- face behind: a copy of that body, kept on the bearer for the fight (models/stolen_faces.lua). Only a count; the
-- two pieces that carry it are what spend it, and a body carrying both banks each kill once.
return {
    name = "Faces of the Slain",
    description = "Each foe you kill leaves you its face for the rest of the fight.",
    notAReaction = true,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen) or fallen.lastAttacker ~= u or fallen.side == u.side then return end
        require("models.stolen_faces").noteKill(u, fallen)
    end,
}
