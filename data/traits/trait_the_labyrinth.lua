-- THE LABYRINTH: the Minotaur's own rules, on its organ (utility_the_labyrinth; models/labyrinth.lua has the
-- whole of them). The fight opens in a maze; the beast walks through the maze's walls and breaks them; every
-- third turn of its own the unbroken walls slide; and below a third of its health it puts its head down and
-- goes into Fury.
--
-- `notAReaction`: every hook here is what the beast IS, read off the board and its own bar, not a reflex to a
-- blow -- so a Stun on it does not stop the maze moving or the head going down (Trait.onDamaged's header).
local Labyrinth = require("models.labyrinth")

return {
    name = "The Labyrinth",
    description = "Fights in a maze it walks through. Every third turn the walls slide. Below a third of its health, it goes into Fury.",
    labyrinth = true,
    throughTheWalls = true,
    headDownOnLethal = true, -- Trait.trySurvive: a blow that would fell it from above the line puts its head down instead
    notAReaction = true,
    onCombatStart = function(ctx)
        if ctx.combat and ctx.unit then Labyrinth.lay(ctx.combat, ctx.unit) end
    end,
    onTurnEnd = function(ctx)
        Labyrinth.onTurnEnd(ctx.combat, ctx.unit)
    end,
    onDamaged = function(ctx)
        if Labyrinth.belowHeadDown(ctx.unit) then Labyrinth.headDown(ctx.combat, ctx.unit) end
    end,
}
