-- SCALE OF HEARTS: the Weighers' trophy rule (data/items/utility/utility_scale_of_hearts.lua), on an Inquisitor.
-- Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2). The scale turned on the bearer's own blows: a foe whose
-- heart is the heavier -- more current health than the bearer -- is struck for 4 more.
local function current(u)
    local h = u and u.char and u.char.stats and u.char.stats.health
    return (type(h) == "table" and h.current) or 0
end

return {
    name = "Scale of Hearts",
    description = "Your blows deal +4 against a foe with more current health than you.",
    perBlow = 4,
    damageBonusVs = function(ctx)
        if not (ctx.unit and ctx.target) then return 0 end
        if current(ctx.target) > current(ctx.unit) then return ctx.param("perBlow", 4) end
        return 0
    end,
}
