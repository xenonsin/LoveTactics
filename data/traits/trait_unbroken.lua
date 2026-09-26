-- THE UNBROKEN AXE's rule (data/items/weapon/weapon_unbroken_axe.lua), the Berserker's streak without the
-- compulsion (approved as pitched, 2026-09-26, "The Orcs of Wrath"). +2 Damage for each turn in a row a blow
-- from THIS axe landed, up to +10; a turn without one resets it. Warpaint (trait_warpaint) counts every hit;
-- the two keep their own counts and the Unbroken badge carries the longer (models/streak.lua), so both worn is
-- not +20.
return {
    name = "Unbroken",
    description = "Each turn in a row this axe lands a hit, increase damage by 2, up to 10. A turn without one resets it.",
    notAReaction = true,
    onCast = function(ctx)
        if (ctx.damageDealt or 0) > 0 and ctx.unit and ctx.item and ctx.item.id == "weapon_unbroken_axe" then
            require("models.streak").hit(ctx.unit, "axe")
        end
    end,
    onTurnEnd = function(ctx) require("models.streak").settle(ctx.combat, ctx.unit, "axe") end,
}
