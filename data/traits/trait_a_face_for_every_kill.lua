-- A FACE FOR EVERY KILL: the Faceless Assassin's rule (data/items/utility/utility_a_face_for_every_kill.lua), after
-- the Faceless Men. Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2). Machinery in models/stolen_faces.lua.
--
--   ITS HAND IS ITS KILLS. Not dealt: at the bell its hand is whatever companions the save remembers it
--     downing (`player.facesTaken`), and every body it kills after that joins it.
--   IT WALKS IN WEARING A COMMON FACE -- one of its own side's, else a glass-thing -- and is held in it
--     (`faceLocked`) until it strikes, so it stands among the pack as one of them. Its first damaging blow lets
--     the read go.
--   ITS FIRST BLOW OUT OF ANY FACE IS A CRITICAL (`critOutOfAFace`, Combat.forcesCrit). A landed blow spends it
--     for the face it was struck from; a new face is a new critical.
--   ONE OF YOURS, DOWNED, IS WORN AT ONCE -- a copy of that body, kit and all -- and written to the save, so the
--     same companion is in its hand the next time the company meets it.
return {
    name = "A Face for Every Kill",
    description = "Its hand is the faces of what it has killed. Its first blow out of any face is a critical.",
    critOutOfAFace = true,
    notAReaction = true,
    onCombatStart = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and u.alive and combat) then return end
        local SF = require("models.stolen_faces")
        local Faces = require("models.faces")
        u.faceHand = SF.remembered(u.char and Faces.originalChar(u).id)
        u.faceLocked = true
        local disguise = SF.disguiseFor(combat, u)
        if disguise then Faces.wear(combat, u, disguise) end
    end,
    onCast = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) or (ctx.damageDealt or 0) <= 0 then return end
        u.faceCritSpent = u.faceWorn
        u.faceLocked = nil -- it has shown itself: from here its own read chooses among its kills
    end,
    onAnyDeath = function(ctx)
        local u, combat, fallen = ctx.unit, ctx.combat, ctx.fallen
        if not (u and u.alive and fallen and fallen.char) or fallen.lastAttacker ~= u then return end
        if fallen.side == u.side then return end
        local SF = require("models.stolen_faces")
        local Faces = require("models.faces")
        local face = SF.copyOf(fallen)
        if not face then return end
        u.faceHand = u.faceHand or {}
        table.insert(u.faceHand, 1, face)
        -- ONE OF YOURS: worn at once, and remembered past this fight.
        if fallen.side == "party" then
            local keeper = Faces.originalChar(u).id
            SF.remember(keeper, Faces.originalChar(fallen))
            ctx.log("action", string.format("%s takes %s's face.", (u.char and u.char.name) or "It",
                (fallen.char and fallen.char.name) or "its victim"), { u, fallen })
            Faces.wear(combat, u, face)
        end
    end,
}
