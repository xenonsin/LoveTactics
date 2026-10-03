-- HER GARDEN: three statues of past challengers stand on Medusa's board, Petrified (character_stone_challenger),
-- and at her half health they crack open and fight (models/gorgon.lua's Gorgon.wakeGarden). Read off her own bar
-- once, on the blow that crosses the line -- `notAReaction`, so a stun does not keep the garden asleep.
return {
    name = "Her Garden",
    description = "At half health, the statues on its side crack open and fight.",
    notAReaction = true,
    at = 0.5,
    onDamaged = function(ctx)
        local u = ctx.unit
        if u.gardenWoken then return end
        local hp = u.char.stats.health
        local max = require("models.combat").unreservedMax(u.char, "health")
        if (hp.current or 0) > max * ctx.def.at then return end
        u.gardenWoken = true
        require("models.gorgon").wakeGarden(ctx.combat, u)
    end,
}
