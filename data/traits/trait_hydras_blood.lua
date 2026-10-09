-- HYDRA'S BLOOD: the poison Heracles dipped his arrows in (data/items/utility/utility_hydras_blood.lua,
-- models/lerna.lua). Two halves:
--   * every weapon blow the bearer lands inflicts Poison -- Barbed Fletching's shape (trait_barbed_fletching): a
--     blow that missed leaves nothing, and an ability is its own decision about what it inflicts;
--   * a Poisoned foe that falls passes its Poison to every foe beside it (onAnyDeath), whoever felled it.
return {
    name = "Hydra's Blood",
    description = "Your blows Poison. When a Poisoned foe falls, its Poison spreads to every foe beside it.",
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        if not (ctx.item and ctx.item.type == "weapon") then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not (target and target.alive) or target.side == ctx.unit.side then return end
        ctx.applyStatus(target, "status_poison", { applier = ctx.unit })
    end,
    onAnyDeath = function(ctx)
        require("models.lerna").spreadPoison(ctx.combat, ctx.unit, ctx.fallen)
    end,
}
