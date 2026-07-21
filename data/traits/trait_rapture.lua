-- Luxuria's rule, and Lust's in one hook: lust "takes what is not offered" (docs/story.md, which flags
-- this as the wired-but-unwritten trait). Where Greed takes the foe itself -- Charm, the tool that turns
-- an ally (data/items/ability/ability_charm.lua) -- Lust takes what you KEPT: the reserves you were
-- hoarding rather than spending. Every time she acts on a foe she draws off the stamina and mana they
-- did not offer up, and takes it into herself as health.
--
-- The counterplay is the sin stated as tactics: SPEND. A party that pours its reserves out each turn has
-- nothing held back for her to find; a party that husbands them for the big turn is feeding her the whole
-- time. And the one unit she can never draw from is the one that already gave everything away -- Amana
-- (data/traits/trait_devotion_unbidden.lua), whose Unbidden rule this hook checks and passes over.
--
-- Fired from onCast (Trait.onCast), so it rides on any offensive action and, like every general's rule,
-- travels with the relic lifted off her body (data/items/utility/utility_reliquary_unbidden.lua): carry
-- it and you take what your foes withhold, and become the thing you killed.
return {
    name = "Rapture",
    description = "Draws off the stamina and mana a foe held back, and takes it into herself.",
    stamina = 12, -- reserve seized from each pool on a hit
    mana = 12,
    onCast = function(ctx)
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        -- A will that gave everything away holds nothing back to seize (Amana's Unbidden rule).
        if require("models.trait").has(target, "trait_devotion_unbidden") then
            ctx.log("action", string.format("%s has held nothing back.", (target.char and target.char.name) or "The target"))
            return
        end
        local taken = ctx.drain(target, "stamina", ctx.def.stamina) + ctx.drain(target, "mana", ctx.def.mana)
        if taken > 0 then
            ctx.heal(ctx.unit, math.floor(taken / 2 + 0.5)) -- she takes it into herself
            ctx.log("action", string.format("%s takes what was not offered.", (ctx.unit.char and ctx.unit.char.name) or "She"))
        end
    end,
}
