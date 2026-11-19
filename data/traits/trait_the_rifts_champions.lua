-- THE RIFT'S CHAMPIONS: the Faceless Champion's rule (data/items/utility/utility_the_rifts_champions.lua).
-- Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2); it replaced a Duelist whose rule was "whichever your
-- attacker lacks", which the author found "not exciting".
--
-- Its hand is not dealt from the whole bestiary: it is the rift's champions (StolenFaces.champions -- every one
-- the review named that may be a face), set before the race deals, and Reshape swaps it to whichever answers the
-- nearest of the company. Each face is worn with its signature rule, which rides its grid (Untouchable, the
-- Blood Ring's Challenge, the Lesson, the chi), and opens the way it would have at the bell: the face's own race
-- opener runs as it is put on (the Bladedancer is Unblemished again), and what it laid comes off with it.
--
-- THE TELEGRAPH (creature identity pass, 2026-11-19). It picked its face by the same nearest-foe read as every
-- Faceless, so the player met each champion only once it was already on. Now it commits its NEXT face at the end
-- of each turn -- and once at the bell, beside the face it opens in -- and names it on a badge (status_next_face,
-- Faces.telegraph). Reshape wears exactly that face next turn. The player chooses who stands nearest it.
return {
    name = "The Rift's Champions",
    description = "Wears the rift's champions, each with its rule. At the end of its turn it names the face it wears next.",
    notAReaction = true,
    onCombatStart = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and u.alive and combat) then return end
        local SF = require("models.stolen_faces")
        u.faceHand = SF.champions()
        local Faces = require("models.faces")
        Faces.reshape(combat, u)
        Faces.telegraph(combat, u)
    end,
    onTurnEnd = function(ctx)
        if ctx.unit and ctx.unit.alive and ctx.combat then require("models.faces").telegraph(ctx.combat, ctx.unit) end
    end,
    onFaceWorn = function(ctx)
        if ctx.unit and ctx.unit.alive and ctx.combat then
            require("models.stolen_faces").openFace(ctx.combat, ctx.unit)
        end
    end,
}
