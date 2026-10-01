-- THE RIDDLE: the Sphinx's rule, and the Sphinx's Riddle's (models/pride_elites.lua; "Pride's Bestiary",
-- 2026-09-30). The Sphinx is never wrong.
--
-- A ROUND IS THE ASKER'S OWN TURN CYCLE: the game has a timeline and no rounds, so the riddle is asked when
-- the fight opens and at the end of each of the asker's turns, and judged at the end of the next. Each is dealt
-- off the fight's own seed and never the same twice running, so a repeat visit is not a repeat fight. The
-- riddle is shown as a log line and as a badge on the asker naming it (status_riddle_*).
--
-- On the SPHINX (its organ, data/items/utility/utility_the_riddle.lua) the riddle is asked of its foes, and it
-- WARDS: unanswered, the Sphinx takes no damage at all (`wards`, read by PrideElites.ward). A round that meets
-- the riddle leaves it Answered -- open to damage until its next turn ends; a round that fails heals it a tenth.
--
-- On the SPHINX'S RIDDLE (data/items/utility/utility_sphinxs_riddle.lua) it is asked of the bearer's own side,
-- does not ward, does not heal, and a met round gains the bearer Empowered (`traitParams`).
--
-- What the round saw is recorded off two broadcasts: every cast (onCast / onAnyCast, a strike being any cast
-- whose ability deals damage) and every turn's end (onTurnEnd / onAnyTurnEnd, for who moved).
local PrideElites = require("models.pride_elites")

return {
    name = "The Riddle",
    description = "Asks a riddle each turn. Unanswered, takes no damage; met, can be hurt until its next turn; failed, heals 10%.",
    riddler = true, -- Sundered, the Sphinx asks nothing and wards nothing (Trait.flag is gagged)
    asks = "foes",                      -- whose answer counts: its foes, or (`own`) its bearer's side
    wards = true,                       -- unanswered, the bearer takes no damage
    reward = PrideElites.ANSWERED,      -- what a met round leaves on the bearer
    failHeal = PrideElites.FAIL_HEAL,   -- what a failed round heals it, as a share of its health
    onCombatStart = function(ctx)
        if ctx.unit and ctx.unit.alive then PrideElites.pose(ctx.combat, ctx.trait, ctx.unit) end
    end,
    onCast = function(ctx)
        PrideElites.noteCast(ctx.combat, ctx.trait, ctx.unit, ctx.unit, ctx.item, ctx.ability, ctx.tx, ctx.ty)
    end,
    onAnyCast = function(ctx)
        PrideElites.noteCast(ctx.combat, ctx.trait, ctx.unit, ctx.caster, ctx.castItem, ctx.castAbility,
            ctx.tx, ctx.ty)
    end,
    onAnyTurnEnd = function(ctx)
        PrideElites.noteTurnEnd(ctx.trait, ctx.unit, ctx.actor)
    end,
    onTurnEnd = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive) then return end
        PrideElites.noteTurnEnd(ctx.trait, unit, unit)
        PrideElites.judge(ctx.combat, ctx.trait, unit)
    end,
}
