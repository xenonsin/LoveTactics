-- EACH HEAD A THIRD: Cerberus's body ("The Crown's Bestiary", slice C, approved 2026-10-09). "Each head is a third of
-- its bar and goes quiet when that third is gone."
--
-- The three heads are grown at the bell off the three Cerberus's Head pieces in its grid (Combat.spawnHeads), and
-- here, once they stand, the bar is cut into them: each head holds a third, and the body's bar is their sum
-- (models/gate_and_pit.lua). A blow on the body lands on the fullest head (`eachHeadAThird`, read by
-- Combat.dealFlatDamage); a head lost is a third gone, and the last head lost fells the body.
local function GatePit() return require("models.gate_and_pit") end

return {
    name = "Each Head a Third",
    description = "Its bar is its three heads. A blow on the body lands on the fullest head; a head at 0 goes quiet.",
    eachHeadAThird = true,
    notAReaction = true,
    onCombatStart = function(ctx) GatePit().split(ctx.combat, ctx.unit) end,
    onSummonLost = function(ctx)
        local lost = ctx.lost
        if lost and lost.headOf == ctx.unit then GatePit().sync(ctx.combat, ctx.unit) end
    end,
}
