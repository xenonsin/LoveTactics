-- THE FLAYING: the Skin-Thief's rule (data/items/utility/utility_the_flaying.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary"); round 1 had it take a body's resists, and the author's note was "taking resists is a weak
-- concept" -- so round 2 has it take the face itself.
--
-- Its hit flays one of the company: that body is Halted for 2 turns (the existing status -- no abilities at all)
-- and the thief wears that body's face for the same 2 turns (status_stolen_face, models/stolen_faces.lua),
-- casting its abilities. One face at a time. The face comes back when the time ends or the thief dies: the
-- Stolen Face's own expiry lifts the Halt it laid.
--
-- The Halt is resistible, so a strong will shortens it -- and the stolen face is held exactly as long as the
-- Halt that landed, never longer. A Halt shrugged off entirely flays nothing.
return {
    name = "The Flaying",
    description = "Its hit Halts one of the company for 2 turns, and it wears that body's face until then.",
    turns = 2,
    onBlowLanded = function(ctx)
        local u, combat, target = ctx.unit, ctx.combat, ctx.target
        if not (u and u.alive and target and target.alive and target.side ~= u.side) then return end
        local Status = require("models.status")
        local SF = require("models.stolen_faces")
        if Status.has(u, SF.STATUS) then return end -- one face at a time
        local face = SF.copyOf(target)
        if not face then return end
        local halt = ctx.applyStatus(target, "status_halted",
            { duration = ctx.param("turns", 2) * SF.TURN, applier = u })
        if not halt then return end
        ctx.log("action", string.format("%s flays %s and wears the face.", (u.char and u.char.name) or "It",
            (target.char and target.char.name) or "its victim"), { u, target })
        SF.wearFor(combat, u, face, halt.remaining, target)
    end,
}
