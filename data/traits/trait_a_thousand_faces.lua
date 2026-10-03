-- A THOUSAND FACES: the Faceless racial rule, carried on its grant (data/items/utility/utility_faceless_blood.lua).
-- Reviewed 2026-10-01..03 ("Envy's Bestiary").
--
-- At the opening bell it deals the hand (unless the body already holds one -- the Assassin's is its kills, the
-- Champion's is the rift's champions) and puts on the first face, so the fight opens with the Faceless already
-- wearing something. The turn-top read rides on status_faceless, which a transform never touches.
--
-- `faceHandSize` (a blueprint field, read off the body's own def) sizes the hand; the line soldier's is three.
return {
    name = "A Thousand Faces",
    description = "Carry a hand of faces. Each turn, wear the one that best answers the nearest foe.",
    onCombatStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        local Faces = require("models.faces")
        ctx.applyStatus(u, Faces.STATUS, { applier = u })
        if not u.faceHand then
            local def = u.char and require("models.character").defs[u.char.id]
            Faces.deal(ctx.combat, u, (def and def.faceHandSize) or Faces.HAND)
        end
        Faces.reshape(ctx.combat, u)
    end,
}
