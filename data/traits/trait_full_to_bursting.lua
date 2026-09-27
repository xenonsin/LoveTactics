-- FULL TO BURSTING: the Gorged's rules (data/items/utility/utility_full_to_bursting.lua; models/gorged.lua). Every
-- blow that wounds it and leaves it standing spills a blood pool beside it; the blow that crosses half its health
-- bursts it -- the floor round it floods, it shrinks to one tile, it moves faster, and it is in Bloodlust for good.
--
-- NOT A REFLEX (`notAReaction`): a stunned Gorged still bleeds, and still bursts at half. Read off its own bar on
-- the blow that crosses the line, as trait_boss_phases reads a phase -- so a blow that kills it outright spills
-- nothing and skips the burst, the same honest reading.
return {
    name = "Full to Bursting",
    description = "Each wound spills a blood pool beside it. At half health it bursts: the tiles round it flood.",
    notAReaction = true,
    onDamaged = function(ctx)
        local unit, combat = ctx.unit, ctx.combat
        if not (unit and unit.alive and combat) then return end
        local Gorged = require("models.gorged")
        local hp = unit.char.stats.health
        if not unit._burst and (hp.max or 0) > 0 and (hp.current or 0) / hp.max <= Gorged.BURST_AT then
            Gorged.burst(combat, unit)
            return
        end
        Gorged.spill(combat, unit)
    end,
    onTurnEnd = function(ctx)
        require("models.gorged").holdBloodlust(ctx.combat, ctx.unit)
    end,
}
