-- THE SECOND HOUND: a body that is being fought by one thing stands. A body that is being fought by
-- two leaves.
--
-- The Meandering Stag's flight rule, cut down small enough for a person to carry. The stag itself
-- refuses to be surrounded by walking away from whoever is nearest, every turn, forever
-- (models/ai.lua's `quarry`); this is the one clause of that a player can have, and the count is the
-- whole item. It does not fire against the first attacker, ever. A duel is not being surrounded.
--
-- IT FIRES ON THE BLOW, NOT ON THE APPROACH, and that is a compromise the engine chose rather than the
-- design. What the fight's own rule does is answer the MOMENT a second body closes -- but there is no
-- trait hook for "somebody stepped next to me": Trait's seams are onDamaged, onCast, onStatusApplied,
-- onDeath and onSummonLost, plus the standing `live` claim and the turn-start flags. So the trigger is
-- the next blow that lands while the bearer is hemmed in, which is later and, in play, close enough --
-- a second attacker who has closed and not yet swung has not cost the bearer anything yet.
--
-- IT STEPS AWAY FROM THE ATTACKER rather than beside it, which is the whole difference between this
-- and the Slipstep it otherwise resembles (trait_slipstep puts a rogue BEHIND whoever hit it and
-- stabs). This does not answer. It breaks off. The step is one tile, directly away where the ground
-- allows and to the nearest open tile in that quarter where it does not.
--
-- ON A COOLDOWN, because the state that fires it -- two foes adjacent -- is exactly the state a body
-- cannot get out of in one step. Without it, a surrounded bearer would teleport once per incoming blow
-- and never be hit twice in a turn, which is not "gives ground" but "cannot be focused".
--
-- The arrival springs whatever is on the tile -- a trap, a fire, blight -- exactly as a walk would.
-- Giving ground is still choosing ground.
local ADJACENT = 1

return {
    name = "The Second Hound",
    description = "Struck while two or more foes are on you, you give a step of ground.",
    cooldown = 10, -- ~2 turns: it answers being surrounded, not every blow
    onDamaged = function(ctx)
        if ctx.onCooldown("trait_the_second_hound") then return end
        local attacker = ctx.attacker
        if not (attacker and attacker.alive) then return end

        -- THE COUNT, and it is the item. `ctx.count` is the same live field read trait_single_combat
        -- makes -- what is standing next to me right now -- so nothing is banked and a bearer whose
        -- second attacker has already fallen gets nothing.
        if ctx.count(ADJACENT, "foe") < 2 then return end

        -- Directly away from whoever struck, clamped to one step per axis so a diagonal attacker
        -- pushes the bearer diagonally rather than nowhere.
        local dx = ctx.unit.x - attacker.x
        local dy = ctx.unit.y - attacker.y
        dx = (dx > 0 and 1) or (dx < 0 and -1) or 0
        dy = (dy > 0 and 1) or (dy < 0 and -1) or 0
        if dx == 0 and dy == 0 then return end

        -- openTileNear does the settling: the tile straight back if it is free, otherwise the nearest
        -- open ground in that direction. Nil when there is nowhere to go, which is the honest failure
        -- -- a bearer in a corner is in a corner.
        local x, y = ctx.openTileNear(ctx.unit.x + dx, ctx.unit.y + dy)
        if not x then return end

        -- Cost last, after every free refusal above (models/trait.lua, `ctx.pay`): a bearer with an
        -- empty pool stays where it is and is billed nothing for the step it did not take.
        if not ctx.pay() then return end
        ctx.setCooldown("trait_the_second_hound", ctx.def.cooldown or 0)
        ctx.log("action", string.format("%s gives ground.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.teleport(x, y)
    end,
}
