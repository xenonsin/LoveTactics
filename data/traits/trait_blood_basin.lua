-- THE BLOOD BASIN: the basin's own rule (data/characters/character_blood_basin.lua; models/basin.lua). It fills
-- with every point of Bleed damage taken anywhere (`bloodBasin`, read by Basin.onBleed); it is set in the middle
-- of the board as the fight opens; and with nobody left on its side to bathe, it goes with them.
local Basin = require("models.basin")

return {
    name = "Blood Basin",
    description = "Fills with every point of Bleed damage taken anywhere. When full, the Countess bathes in it.",
    bloodBasin = true,
    notAReaction = true,
    onCombatStart = function(ctx)
        if ctx.combat and ctx.unit then Basin.center(ctx.combat, ctx.unit) end
    end,
    onAnyDeath = function(ctx)
        local combat, basin = ctx.combat, ctx.unit
        if not (combat and basin and basin.alive) or not Basin.orphaned(combat, basin) then return end
        require("models.combat").fell(combat, basin)
        ctx.log("action", "With nobody left to bathe in it, the basin goes still.", basin)
    end,
}
