-- IT EATS WHAT YOU CUT OFF: when one of the Chimera's heads is broken, the lion turns round and eats it --
-- it heals and is Gorged for a couple of turns (status_gorged). Approved on review (2026-09-23) as the
-- line that makes a break a TIMING decision rather than a free win: the company takes a mouth off for
-- good and has to be ready for the spike that follows.
--
-- On onSummonLost, which fires to the SUMMONER alone when one of its conjurations dies -- and a head is
-- exactly that to its body (Combat.growHead). A head DISMISSED because the body fell first never reaches
-- the hook, so a dead lion eats nothing.
return {
    name = "It Eats What You Cut Off",
    description = "When one of its heads is broken, it eats it: heals 15 and is Gorged.",
    heal = 15,
    onSummonLost = function(ctx)
        local lost, u = ctx.lost, ctx.unit
        if not (lost and lost.headOf == u and u.alive) then return end
        ctx.heal(u, ctx.param("heal", 15))
        ctx.applyStatus(u, "status_gorged")
        ctx.log("death", string.format("%s eats its own %s.", (u.char and u.char.name) or "It",
            ((lost.char and lost.char.name) or "head"):gsub("^.-'s ", "")), { u, lost })
    end,
}
