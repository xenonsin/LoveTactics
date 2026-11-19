-- GRIEF AT YOUR FORTUNE: the Pale Crone's rule, and the Skirmisher's once it is carried out (data/items/utility/
-- utility_grief_at_fortune.lua, utility_thorned_staff.lua). Reviewed 2026-10-06 ("Envy's Bestiary", round 4).
--
-- Ovid's Envy wastes at the sight of another's success. When a foe of the bearer is healed or freshly blessed
-- where the bearer can see it -- within `reach`, when the granter names one -- the bearer leaps beside it and
-- strikes, once a round. A heal is heard in Combat.applyHeal and a blessing here; both only MARK the leap, which
-- is thrown once the action has finished resolving (models/envy_oneoffs.lua's lunge).
--
-- AND AT YOUR KILLS, ON THE CRONE'S OWN ORGAN (creature identity pass, 2026-11-19: the same-envy-support row). A
-- heal or a blessing was her only trigger, so a company with no support body never once saw her leap. Success is
-- also a kill: with `grievesKills` named by the granter (utility_grief_at_fortune's traitParams), a foe she can
-- see felling a body marks the leap on the killer exactly as a heal does. Off by default, so the Skirmisher's
-- Thorned Staff -- the same rule pointed the other way -- reads heals and blessings only, as it always has.
local function Envy() return require("models.envy_oneoffs") end

return {
    name = "Grief at Your Fortune",
    description = "Once a round, when a foe it can see is healed or blessed, it leaps beside that foe and strikes.",
    griefAtFortune = true,
    onAnyStatusApplied = function(ctx)
        local r = ctx.recipient
        if r and ctx.unit and r.side ~= ctx.unit.side then Envy().noteFortune(ctx.combat, r, ctx.status) end
    end,
    onAnyDeath = function(ctx)
        if not ctx.param("grievesKills", false) then return end
        local fallen = ctx.fallen
        local killer = fallen and fallen.lastAttacker
        if killer and killer.alive and ctx.unit and killer.side ~= ctx.unit.side and fallen.side ~= killer.side then
            Envy().noteFortune(ctx.combat, killer)
        end
    end,
    onAnyCast = function(ctx) Envy().lunge(ctx.combat, ctx.unit) end,
    onAnyTurnEnd = function(ctx) Envy().lunge(ctx.combat, ctx.unit) end,
    -- Its own turn re-arms the leap, and drops one marked and never thrown: it has had its turn to act on it.
    onTurnEnd = function(ctx)
        if ctx.unit then ctx.unit.griefSpent = nil; ctx.unit.lungeAt = nil end
    end,
}
