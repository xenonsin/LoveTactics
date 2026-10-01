-- THREE WISHES: the Wishmaker's rule (utility_three_wishes). Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- Three seams, one per kind of moment, all handing off to models/djinn.lua:
--   onCombatStart   the Lamp is set down beside her, wherever the band dealt it
--   onDamaged       a wound that crosses two-thirds or one-third grants the next wish
--   wishesOnLethal  read by Trait.trySurvive: the blow that would fell her grants what is left, in order
-- Every one of them asks first whether the Lamp still stands. Break it, and she is an elf with a staff.
return {
    name = "Three Wishes",
    description = "While your Lamp stands, it grants a wish at each third of your health.",
    wishesOnLethal = true,
    notAReaction = true, -- a script read off her own bar, not a reflex: a stunned Wishmaker still wishes
    onCombatStart = function(ctx)
        require("models.djinn").seatLamp(ctx.combat, ctx.unit)
    end,
    onDamaged = function(ctx)
        require("models.djinn").onWounded(ctx.combat, ctx.unit)
    end,
}
