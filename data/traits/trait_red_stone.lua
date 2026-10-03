-- RED STONE: the Homunculus's heart (data/items/utility/utility_red_stone_heart.lua; "Envy's Bestiary", 2026-10-03,
-- slice C). The author's note on the first pitch was "homunculi are creations of alchemists, think of full metal
-- alchemist": a made being with a red stone for a heart, holding several lives.
--
-- It opens the fight holding 3 Red Stone (status_red_stone, shown as pips). A killing blow consumes one instead
-- (Trait.trySurvive, `redStone`): it falls, and stands back up at full health at the start of its next turn. At 0
-- it dies for good. While it holds any it heals a tenth of its health each turn. Unclosing stops both, because
-- both are heals (models/envy_seat.lua).
--
-- On the bearer's own turn start (Trait.onAnyTurnStart's own-turn dispatch), not on a status: the stone count can
-- reach 0 on the very blow that felled it, and the body still has to get up from that one.
return {
    name = "Red Stone",
    description = "Opens with 3 Red Stone. A killing blow consumes one; it rises whole next turn. Heals 10% a turn.",
    redStone = true,
    redStoneRises = true,
    notAReaction = true,
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_red_stone", { magnitude = require("models.envy_seat").RED_STONES })
    end,
    onTurnStart = function(ctx)
        require("models.envy_seat").redStoneTurn(ctx.combat, ctx.unit)
    end,
}
