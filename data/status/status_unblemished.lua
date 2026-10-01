-- UNBLEMISHED: an elf that has not yet been wounded (data/traits/trait_unblemished.lua). Reviewed 2026-09-30
-- ("Pride's Bestiary"): "bigger bonus, including range bonuses", and "drop to normal" when it goes.
--
-- ENDS ON THE FIRST WOUND (onDamaged, which fires for a survivor). A blow that draws nothing does not end it: a
-- miss never reaches the hook, and Combat.dealFlatDamage returns before it for a blow a barrier, a Mana Shield or
-- a riposte swallowed whole. The `amount` guard is the belt to those braces. A blow that KILLS needs no hook.
--
-- NO HEAL RESTORES IT. It is not keyed to the health pool at all, which is the point: a Marid's tide or a priest
-- can put every point back and the elf is still marred.
--
-- Not a debuff, so no Cure lifts it, and not something a foe can strip but by wounding.
return {
    name = "Unblemished",
    abbr = "Flaw",
    description = "Unblemished: increases damage and magic damage by 4, luck by 8 and reach by 1, until wounded.",
    color = { 0.900, 0.860, 0.620 }, -- badge tint (pale gold)
    duration = math.huge,
    hideDuration = true,
    statBonus = { damage = 4, magicDamage = 4, luck = 8, range = 1 },
    onDamaged = function(ctx)
        if (ctx.amount or 0) > 0 then ctx.expire() end
    end,
}
