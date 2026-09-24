-- THE PALATE, as a player carries it: the Maw of the Unfed turns into whatever its bearer last killed.
-- Settled on review 2026-09-23 -- "the item morphs depending on the last kill" -- and it is the relic
-- line every general's piece has always carried ("you become the thing you killed") taken literally.
--
-- Land the killing blow on a wolf and the Maw's cell holds the wolf's fangs for the rest of the fight;
-- kill a spider next and it holds Silk Shot instead. A body that gives nothing (a hawk, a demon) turns the
-- relic back into itself. The bell puts the Maw back in its cell whatever it was wearing
-- (Combat.releaseClaims reads `morphOf`), so nothing borrowed ever leaves the fight.
--
-- Credited on `lastAttacker`, the same field every bounty and every kill-credit in the game reads, so a
-- body the bearer bled out with a poison it laid counts as the bearer's kill -- which is what a poisoner
-- would expect it to.
--
-- Gula herself does not carry the Maw: her powers come from Devour (models/palate.lua's Palate.take),
-- which is the other half of this one model. The Maw is what is left of that appetite once it is lifted
-- off her, and it only knows how to kill.
return {
    name = "The Palate",
    description = "Becomes the power of the last body you killed.",
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not (fallen and fallen.lastAttacker == ctx.unit and ctx.item) then return end
        if fallen.side == ctx.unit.side then return end -- a friend's body teaches the Maw nothing
        require("models.palate").morph(ctx.combat, ctx.unit, ctx.item, fallen)
    end,
}
