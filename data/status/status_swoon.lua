-- Swoon: the mushrooms' spore, and the Lust circle's agency taken without its position.
--
-- IT REFUSES HARM AND NOTHING ELSE. A swooning body cannot bring itself to strike anybody -- no weapon
-- swing, no damaging cast -- and may still walk, heal, brace, cleanse and hand a draught across
-- (Status.forbidsHarm, read by Combat.itemBlockReason beside Halted). Halted refuses the act; this
-- refuses only the act that hurts, which is the same line Sloth's status draws one step narrower.
--
-- IT BREAKS ON A HIT, like Sleep, and for Sleep's reason: the answer every character in the game already
-- has is to be struck, so a company can wake its own anvil with a friendly slap at the price of the
-- slap. A Cure lifts it too. What it takes is the NEXT turn's violence, not the fight.
--
-- AND IT IS THE ONE CONTROL ON THIS STRATUM THAT FITS EITHER KIND OF FIGHT. Root holds a body and Wind
-- moves one, and the two are never fielded together (Descent.SINS' Lust entry); a spore does neither,
-- so the mushroom folk that carry it may stand in any fight the circle rolls.
return {
    name = "Swoon",
    abbr = "Swn",
    description = "Swooning: cannot deal damage. Any hit ends it.",
    color = { 0.839, 0.643, 0.749 }, -- badge tint (spore pink)
    duration = 12,                -- about two turns: the next swing, and the one after it
    debuff = true,                -- Cure/Panacea lift it
    resistible = "magical",       -- warded by magicDefense + statusResist, halved on every repeat
    disablesHarm = true,          -- Status.forbidsHarm: refuses every damaging item, and only those
    onDamaged = function(ctx)
        if (ctx.amount or 0) <= 0 then return end
        ctx.log("status", string.format("%s is shaken out of the swoon.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.expire()
    end,
}
