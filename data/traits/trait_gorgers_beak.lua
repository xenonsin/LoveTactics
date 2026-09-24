-- GORGER'S BEAK: every consumable you use this fight gives you +2 Damage for the rest of it, up to three.
-- The griffin's appetite, for the Warbrewer, whose shelf is draughts; approved on review (2026-09-23), and
-- it outlived the griffin mechanic that first inspired it (Gorges on the Take was denied with stealing).
return {
    name = "Gorger's Beak",
    description = "Each consumable you use this battle gives +2 damage for the rest of it, up to 3 times.",
    per = 2,
    cap = 3,
    onCombatStart = function(ctx) ctx.trait.stacks = 0 end,
    onCast = function(ctx)
        -- ctx.item here is the item just USED (onCast shadows the granting item -- see models/trait.lua).
        local used = ctx.item
        if not (used and used.type == "consumable") then return end
        ctx.trait.stacks = ctx.trait.stacks or 0
        if ctx.trait.stacks >= ctx.param("cap", 3) then return end
        ctx.trait.stacks = ctx.trait.stacks + 1
        ctx.addBonus("damage", ctx.param("per", 2))
    end,
}
