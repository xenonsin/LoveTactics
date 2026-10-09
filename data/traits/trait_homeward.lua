-- HOMEWARD: the wisp's whole rule (character_archon_wisp). It walks toward its body -- models/ai.lua's `gather`
-- walk reads the `seeksBody` flag and asks models/spirit.lua where home is -- and at the end of each of its own
-- turns, if it is beside the body, the body stands back up and the wisp is spent.
--
-- WHY THE TURN'S END AND NOT ITS ARRIVAL ON A TILE: a body can only be raised on a tile nobody stands on
-- (Combat.reanimate refuses an occupied one), so the wisp ends BESIDE the body, never on it -- and a company that
-- puts one of its own on the body has shut the door. That is the counter the author approved ("stand on the body
-- so it can't get in"), and it falls out of the raise's own gate rather than being written twice.
return {
    name = "Homeward",
    description = "Walks back to the body it tore loose from. Ending a turn beside it raises the body at half health.",
    seeksBody = true,
    onTurnEnd = function(ctx)
        require("models.spirit").tryArrive(ctx.combat, ctx.unit)
    end,
}
