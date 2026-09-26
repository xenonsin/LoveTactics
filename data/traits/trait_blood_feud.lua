-- BLOOD FEUD: the goblin's racial rule, carried on its grant (data/items/utility/utility_blood_feud.lua).
-- Approved as pitched (2026-09-26, "The Goblins of Wrath").
--
-- A goblin that is hit marks whoever hit it as its side's Feud (models/feud.lua). Every goblin deals +2 to
-- the Feud (damageBonusVs, read at blow time and pure, since the forecast asks it on every hover), and the
-- AI sends any goblin that can reach the Feud this turn at it and nothing else (AI.preempt reads the
-- `bloodFeud` flag). A player's hired goblin keeps the +2 and none of the compulsion.
--
-- NOT A REFLEX (`notAReaction`): a stunned goblin still remembers who hit it. The mark is what the body IS,
-- not something it does about the blow, so hard control does not gag it (Trait.onDamaged).
local BONUS = 2

return {
    name = "Blood Feud",
    description = "When a goblin is hit, whoever hit it becomes the Feud. Increase damage by 2 against the Feud.",
    bloodFeud = true,
    notAReaction = true,
    onDamaged = function(ctx)
        local attacker = ctx.attacker
        if not (attacker and attacker.alive and ctx.unit and attacker.side ~= ctx.unit.side) then return end
        require("models.feud").mark(ctx.combat, attacker, ctx.unit)
    end,
    damageBonusVs = function(ctx)
        if not (ctx.unit and ctx.target) then return 0 end
        return require("models.feud").isFeudOf(ctx.unit, ctx.target) and BONUS or 0
    end,
}
