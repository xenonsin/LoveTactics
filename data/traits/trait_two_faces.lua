-- TWO FACES (utility_two_faces): the Colossus's rule. Reshape (status_faceless) puts on the first face at the top
-- of the turn; this fires after it (onTurnStart runs past the status sweep) and folds the runner-up's kit into the
-- free cells (Masks.foldSecondFace). At the opening bell it deals the hand and reads first itself, because this
-- organ sits ahead of the race's grant in the grid and would otherwise fold before there is a face to fold beside.
--
-- THE SEAM (creature identity pass, 2026-11-19). Two random kits at once, and its header stated no counter. Now
-- using a piece the second face lent opens the seam between the two faces (status_seam_open, until its next turn
-- starts), and the next blow that lands on it while the seam is open tears the lent kit off for the rest of the
-- fight (`secondFaceTorn`): it is one face from then on. Its lever is ORDER in time -- hold a blow for the turn
-- after it reaches for what it borrowed. (The row said "hitting the lent-kit side"; the game has no facing, and
-- a side of a 2x2 body nobody can see is not a lever, so the side became the moment.)
local SEAM = "status_seam_open"

local function fold(ctx)
    local u = ctx.unit
    if not (u and u.alive and ctx.combat) or u.secondFaceTorn then return end
    require("models.masks").foldSecondFace(ctx.combat, u)
end

-- Tear the lent kit off and keep it off. Returns how many pieces came away.
local function tear(ctx)
    local u, combat = ctx.unit, ctx.combat
    local Character = require("models.character")
    local n = 0
    for i = 1, Character.MAX_INVENTORY do
        local item = u.char.inventory[i]
        if item and item.lentByFace then u.char.inventory[i] = nil; n = n + 1 end
    end
    u.secondFaceTorn, u.secondFace, u._secondFaceShape = true, nil, nil
    ctx.clearStatus(u, SEAM)
    require("models.combat").refreshPassives(u)
    require("models.trait").attach(u, combat)
    ctx.log("status", string.format("The seam gives, and %s's second face tears away.",
        (u.char and u.char.name) or "the heap"), u)
    return n
end

return {
    name = "Two Faces",
    description = "Wears a second face's kit beside its first. Using that kit opens a seam; the next blow tears the kit off.",
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
    -- It reached for what the second face lent: the seam shows.
    onCast = function(ctx)
        local u = ctx.unit
        if u and u.alive and not u.secondFaceTorn and ctx.item and ctx.item.lentByFace then
            ctx.applyStatus(u, SEAM, { applier = u })
        end
    end,
    -- A blow through the open seam tears the second face away.
    onDamaged = function(ctx)
        local u = ctx.unit
        if u and u.alive and not u.secondFaceTorn and require("models.status").has(u, SEAM) then tear(ctx) end
    end,
}
