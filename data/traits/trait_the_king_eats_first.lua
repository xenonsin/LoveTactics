-- THE KING EATS FIRST: the Lioness's rule (data/items/utility/utility_the_king_eats_first.lua). Approved
-- 2026-09-30 on Pride's bestiary review.
--
-- While a Lion of her side stands, her blows cannot take a foe below 1 health (Trait.sparesQuarry, read by
-- Combat.dealFlatDamage before either death path), and a foe she brings to 1 is Rooted (onBlowLanded). She holds
-- the prey for him; the Lion's planner goes for held prey first (AI targetPref "held").
--
-- "A Lion" is any body of her side carrying the Lion's Share, read off the board at the blow, so the moment he
-- falls she kills like anything else. That is the fight's question: fell him and the lionesses kill freely, leave
-- him and your bodies live but stand Rooted waiting for him.
local function kingStands(combat, unit)
    local Trait = require("models.trait")
    for _, u in ipairs(combat and combat.units or {}) do
        if u ~= unit and u.alive and u.side == unit.side and Trait.has(u, "trait_the_lions_share") then
            return true
        end
    end
    return false
end

return {
    name = "The King Eats First",
    description = "While a Lion of her side stands, her blows leave a foe at 1 health, and Rooted.",
    sparesQuarry = function(combat, unit) return kingStands(combat, unit) end,
    onBlowLanded = function(ctx)
        local t = ctx.target
        local hp = t and t.char and t.char.stats and t.char.stats.health
        if not (hp and hp.current == 1 and kingStands(ctx.combat, ctx.unit)) then return end
        ctx.applyStatus(t, "status_root", { applier = ctx.unit })
    end,
}
