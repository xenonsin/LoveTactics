-- HOSANNA: the Throne's third phase, which overlaps the other two (reviewed 2026-09-30, "Pride's Bestiary"). At
-- each quarter of its health -- 75%, 50%, 25% -- two Heralds are called (models/choir.lua's Choir.hosanna), and
-- they arrive on the board's own reinforcement telegraph: marked tiles, a turn's warning, and a body standing on a
-- mark turns that Herald back. A blow that spans two quarters calls two pairs, and a blow that kills calls none,
-- the threshold rule data/traits/trait_boss_phases.lua argues. When the Throne falls, whoever it called and has
-- not yet landed is sent home (Choir.silenceHosanna), so a cleared board is a won one.
--
-- NOT A REFLEX, so being stunned does not keep the choir from answering -- not that anything stuns a Throne.
local Choir = function() return require("models.choir") end

return {
    name = "Hosanna",
    description = "At 75%, 50% and 25% health, two Heralds are called to the fight.",
    notAReaction = true,
    onDamaged = function(ctx)
        local u = ctx.unit
        local hp = u.char.stats.health
        local max = require("models.combat").unreservedMax(u.char, "health")
        if not max or max <= 0 then return end
        local fraction = (hp.current or 0) / max
        local at = Choir().HOSANNA_AT
        local t = ctx.trait
        t.called = t.called or 0
        while t.called < #at and fraction <= at[t.called + 1] do
            t.called = t.called + 1
            Choir().hosanna(ctx.combat, u)
            ctx.log("action", string.format("%s cries Hosanna: the choir answers.",
                (u.char and u.char.name) or "The Throne"), u)
        end
    end,
    onDeath = function(ctx)
        Choir().silenceHosanna(ctx.combat, ctx.unit)
    end,
}
