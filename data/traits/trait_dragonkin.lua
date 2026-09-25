-- DRAGONKIN: what makes a body a DRAGON to a kobold (models/devotion.lua), carried on Dragonblood -- the
-- dragon race's organ (data/items/utility/utility_dragonblood.lua), every Dragon Egg's grid, and the
-- Godling's Scale, which makes its wearer the god a hired kobold rallies to.
--
-- APPROVED AS PITCHED (2026-09-24): strike a dragon and every kobold who can see it gains FERVOR; destroy
-- one and they are FORSAKEN. The two hooks are the two halves of one decision the company faces:
--
--   * onDamaged fires only on a SURVIVOR (Combat.dealFlatDamage), so a blow that leaves the dragon
--     standing rallies its line, and a blow that smashes it in one does not -- it breaks them instead.
--     Chipping an egg is the worst of both. `notAReaction`: the kobolds' rage is not the dragon's
--     reflex, so a stunned Godling still rallies whoever sees it hit.
--   * onDeath is skipped for an egg that HATCHED (`unit.hatched`, trait_clutch): a hatching is the god
--     arriving, not the god falling.
return {
    name = "Dragonkin",
    description = "Kobolds who see you struck are driven to Fervor; kobolds who see you destroyed are Forsaken.",
    dragonkin = true,
    notAReaction = true,
    onDamaged = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit and unit.alive) then return end
        local n = require("models.devotion").rally(combat, unit)
        if n > 0 then
            ctx.log("action", string.format("The kobolds see %s struck, and rage.",
                (unit.char and unit.char.name) or "their dragon"), unit)
        end
    end,
    onDeath = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit) or unit.hatched then return end
        local n = require("models.devotion").forsake(combat, unit)
        if n > 0 then
            ctx.log("action", string.format("%s is destroyed, and the kobolds who saw it are Forsaken.",
                (unit.char and unit.char.name) or "Their dragon"), unit)
        end
    end,
}
