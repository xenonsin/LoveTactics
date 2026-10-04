-- THE DROWSE: the cold around Desidia (data/items/utility/utility_the_drowse.lua; "Sloth's Bestiary", slice G,
-- approved word for word). At the end of each round every body on the board, on either side, that did not move that
-- round gains Drowsy; at 3 it falls Asleep (status_drowsy's own rule).
--
-- A round is the stretch between two of the bearer's turns, and a body is judged only if it took a turn inside it
-- (models/desidia.lua's Desidia.drowse) -- standing still is the choice being priced, not being slow.
local function D() return require("models.desidia") end

return {
    name = "The Drowse",
    description = "At the end of each of its rounds, every body that took a turn and did not move gains Drowsy.",
    notAReaction = true,
    onCombatStart = function(ctx) D().snapshot(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) D().drowse(ctx.combat, ctx.unit) end,
}
