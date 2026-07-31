-- Follow-Up: a fighter's nose for the opening. When an ally lands a blow on a foe standing right beside
-- the bearer, the bearer piles on with a swing of its own -- the pincer that punishes a body for being
-- caught between two of you. It reads the board the moment the ally's whole action has resolved
-- (Combat.dispatchAnswer holds the broadcast until then), so it is thrown at where the foe actually ends
-- up, never at a tile a shove already emptied.
--
-- Only a REAL strike opens it, never an answer: the recursion guard lives in the broadcast (see
-- Trait.onAllyStrike / Combat.dispatchAnswer), so a wall of these does not detonate off its own swings.
-- What it costs is what a swing costs, doubled per answer already thrown this round (Trait.answerCost --
-- the same escalating stamina pool counters draw on), so pressing every opening on a crowded line
-- empties the bearer fast rather than being free. Priced by declaring `followUp`, read by ctx.pay.
--
-- The blow re-enters the damage core and so can trip the FOE's own counter, which the dispatch guards
-- (unit._reacting + MAX_DEPTH) keep from looping. Gated `adjacent` by its nature (ctx.gap == 1) rather
-- than by whatever the grid reaches -- a pincer is a thing you do to someone beside you.
return {
    name = "Follow-Up",
    description = "When an ally strikes a foe beside you, spend a swing's stamina to strike it too.",
    followUp = true, -- priced as an escalating answer by ctx.pay / Trait.answerCost
    onAllyStrike = function(ctx)
        local foe = ctx.target
        if not (foe and foe.alive) then return end
        if ctx.gap(foe) ~= 1 then return end     -- only a foe ADJACENT to the bearer
        if not ctx.canReach(foe) then return end -- ...and one a weapon in the grid can actually swing at
        if not ctx.pay() then return end         -- last, so a declined follow-up is never billed
        ctx.log("action", string.format("%s follows up!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(foe)
    end,
}
