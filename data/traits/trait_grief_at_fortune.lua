-- GRIEF AT YOUR FORTUNE: the Pale Crone's rule, and the Skirmisher's once it is carried out (data/items/utility/
-- utility_grief_at_fortune.lua, utility_thorned_staff.lua). Reviewed 2026-10-06 ("Envy's Bestiary", round 4).
--
-- Ovid's Envy wastes at the sight of another's success. When a foe of the bearer is healed or freshly blessed
-- where the bearer can see it -- within `reach`, when the granter names one -- the bearer leaps beside it and
-- strikes, once a round. A heal is heard in Combat.applyHeal and a blessing here; both only MARK the leap, which
-- is thrown once the action has finished resolving (models/envy_oneoffs.lua's lunge).
local function Envy() return require("models.envy_oneoffs") end

return {
    name = "Grief at Your Fortune",
    description = "Once a round, when a foe it can see is healed or blessed, it leaps beside that foe and strikes.",
    griefAtFortune = true,
    onAnyStatusApplied = function(ctx)
        local r = ctx.recipient
        if r and ctx.unit and r.side ~= ctx.unit.side then Envy().noteFortune(ctx.combat, r, ctx.status) end
    end,
    onAnyCast = function(ctx) Envy().lunge(ctx.combat, ctx.unit) end,
    onAnyTurnEnd = function(ctx) Envy().lunge(ctx.combat, ctx.unit) end,
    -- Its own turn re-arms the leap, and drops one marked and never thrown: it has had its turn to act on it.
    onTurnEnd = function(ctx)
        if ctx.unit then ctx.unit.griefSpent = nil; ctx.unit.lungeAt = nil end
    end,
}
