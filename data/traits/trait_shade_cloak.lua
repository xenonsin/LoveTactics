-- SHADE CLOAK: the Shade's trophy rule (data/items/armor/armor_shade_cloak.lua), on an Assassin. Reviewed
-- 2026-10-01..03 ("Envy's Bestiary", round 1).
--
-- The half of Cast by You a company can wear: beside a wall the bearer is Unseen. Not the other half -- open
-- ground does not Limn the wearer -- because the drop text promises the shadow and nothing else. Read at the bell
-- and at the end of each of the bearer's turns, so a turn ended against a wall is spent out of sight until the
-- next one (status_invisible lasts until its holder's next turn).
local function read(ctx)
    local u = ctx.unit
    if u and u.alive then require("models.envy_oneoffs").reshadow(ctx.combat, u, false) end
end

return {
    name = "Shade Cloak",
    description = "While you stand beside a wall, you are Unseen.",
    onCombatStart = read,
    onTurnEnd = read,
}
