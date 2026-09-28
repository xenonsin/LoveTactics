-- THE BROKEN VOW: the asura's rule (models/asura.lua), carried by the race's organ (utility_asura_blood) and
-- by the relic a company monk lifts off Furor (utility_the_broken_vow).
--
-- The pool itself needs no hook: the vow pieces declare `charge = { key = "chi", from = { "hitTaken" } }`,
-- and Combat.chargeDef merges that into the body's own unarmed chi. What this trait does is everything the
-- monk's discipline used to hold back -- the drain on an idle turn, the Burst the moment the pool is full,
-- and, when an asura bursts, the heat it throws to its kin.
--
-- `notAReaction`: none of this is a reflex. A stunned asura still fills when it is struck and still cannot
-- keep what it holds.
return {
    name = "The Broken Vow",
    description = "Chi also fills when struck and drains on an idle turn. At full, Burst at the nearest foe.",
    brokenVow = true, -- the flag (Asura.hasVow)
    notAReaction = true,
    onDamaged = function(ctx)
        require("models.asura").checkBurst(ctx.combat, ctx.unit)
    end,
    onCast = function(ctx)
        local Asura = require("models.asura")
        local ab = ctx.ability
        if ab and ab.asuraBurst then
            ctx.log("action", string.format("%s bursts.", (ctx.unit.char and ctx.unit.char.name) or "It"), ctx.unit)
            if Asura.isAsura(ctx.unit) then Asura.spread(ctx.combat, ctx.unit) end
        end
        Asura.checkBurst(ctx.combat, ctx.unit)
    end,
    onTurnEnd = function(ctx)
        require("models.asura").onTurnEnd(ctx.combat, ctx.unit)
    end,
}
