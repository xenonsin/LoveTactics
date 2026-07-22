-- Gula's rule, and Gluttony's in one hook: gluttony "never stops being hungry" (docs/story.md, "The
-- Hunter's Lodge"). The bargain did not make her stronger, it made her HUNGRY -- it turned the pleasure
-- of the kill into a compulsion that sates less each time and demands the next sooner. So every blow she
-- lands feeds her: she heals on the hit, and a long trade only fattens her.
--
-- The counterplay is the sin stated as tactics: STARVE her. Do not feed the grind -- burst her down and
-- kill clean, deny her the long exchange. A party that stands and swings turn after turn only makes her
-- whole again; temperance as tactics is the discipline to stop feeding the hunt (Kaya's answer,
-- data/items/utility/utility_wolfsong_horn.lua -- root the ring and break the trade).
--
-- Fired from onCast (Trait.onCast), so it rides on any offensive action she commits, exactly as Lust's
-- Rapture does (data/traits/trait_rapture.lua). SHIPPED FIDELITY: this is the heal-on-hit half. The
-- second finale mechanic the chapter describes -- she DEVOURS the fallen, any downed unit adjacent to her
-- consumed to heal toward full -- is deferred new work, as is her two-phase turn into the beast.
--
-- Like every general's rule it travels with the relic lifted off her body
-- (data/items/utility/utility_maw_of_the_unfed.lua): carry the Maw and your own strikes feed you, and
-- you become the thing you killed -- unable to stop taking.
return {
    name = "Ravenous",
    description = "Every blow she lands feeds her: she heals on the hit, and a long trade only fattens her.",
    heal = 8, -- health restored per landed strike; the long trade is her friend
    onCast = function(ctx)
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        ctx.heal(ctx.unit, ctx.def.heal)
        ctx.log("action", string.format("%s feeds on the wound.", (ctx.unit.char and ctx.unit.char.name) or "She"))
    end,
}
