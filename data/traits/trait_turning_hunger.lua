-- THE TURNING HUNGER: at half her health the huntress stops being a woman who hunts and becomes the thing
-- the Lodge exists to hunt (docs/story.md: every Grand Hunter turns; Gula is the one turning NOW).
--
-- This is trait_boss_phases' `transform` response with one line after it, and the line is why it is its
-- own hook rather than a phase table. A transform swaps the grid wholesale for the shape's
-- (models/transform.lua), so the power the huntress was holding would stay behind in the woman's grid --
-- and the beast is the half of the fight that KEEPS what she ate. Palate.regrant puts it back, in the
-- same dispatch, which obeys the phase rule: a threshold pays on the blow that crosses it, never on a
-- turn the party could take away.
--
-- Crossed by a survivor only (onDamaged fires on a body still standing), so a blow that kills her from
-- above half skips the beast entirely -- the honest reading, the same one the Hollow Crown documents.
return {
    name = "The Turning Hunger",
    description = "At half health, she turns into the beast, keeping what she has eaten.",
    at = 0.5,
    into = "character_gula_the_apex",
    onDamaged = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive) or ctx.trait.turned then return end
        local hp = unit.char and unit.char.stats and unit.char.stats.health
        if not (hp and hp.max and hp.max > 0) then return end
        if hp.current > hp.max * ctx.param("at", 0.5) then return end
        ctx.trait.turned = true
        ctx.log("status", "The huntress is gone. What is left of her is hungry.", unit)
        if ctx.transform(ctx.param("into", "character_gula_the_apex")) then
            require("models.palate").regrant(ctx.combat, unit)
        end
    end,
}
