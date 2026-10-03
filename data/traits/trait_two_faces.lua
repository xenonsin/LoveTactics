-- TWO FACES (utility_two_faces): the Colossus's rule. Reshape (status_faceless) puts on the first face at the top
-- of the turn; this fires after it (onTurnStart runs past the status sweep) and folds the runner-up's kit into the
-- free cells (Masks.foldSecondFace). At the opening bell it deals the hand and reads first itself, because this
-- organ sits ahead of the race's grant in the grid and would otherwise fold before there is a face to fold beside.
local function fold(ctx)
    local u = ctx.unit
    if not (u and u.alive and ctx.combat) then return end
    require("models.masks").foldSecondFace(ctx.combat, u)
end

return {
    name = "Two Faces",
    description = "Wear two faces at once: the one Reshape picks, and the next best one's kit beside it.",
    notAReaction = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        local Faces = require("models.faces")
        if not u.faceHand then
            local def = u.char and require("models.character").defs[u.char.id]
            Faces.deal(ctx.combat, u, (def and def.faceHandSize) or Faces.HAND)
        end
        Faces.reshape(ctx.combat, u)
        fold(ctx)
    end,
    onTurnStart = fold,
}
