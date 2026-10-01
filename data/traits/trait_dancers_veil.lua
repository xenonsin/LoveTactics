-- THE DANCER'S VEIL: the Elf Bladedancer's drop, worn (data/items/armor/armor_dancers_veil.lua). Approved
-- 2026-09-30 ("Pride's Bestiary"). Untouchable made a company's: at full health, the first attack each round that
-- rolls to hit is evaded (Combat.veilReady, read by Combat.hitChance). The swing it turns spends it; the end of
-- the wearer's own turn re-arms it.
return {
    name = "Dancer's Veil",
    description = "While at full health, evade the first attack each round that rolls to hit.",
    veil = true,
    notAReaction = true,
    onTurnEnd = function(ctx)
        if ctx.unit then ctx.unit.veilSpent = nil end
    end,
}
