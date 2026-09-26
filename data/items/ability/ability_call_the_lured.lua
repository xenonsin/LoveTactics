-- CALL THE LURED: Vesh's summons, and what he drops. A skeleton comes out of the dark and serves the
-- caster, reserving a fifth of the pool while it stands (the review's "his summons reserve his mana" --
-- Combat.reserve, released when it falls, with no refund). WHICH skeleton is picked by where you aim: a
-- Dwarf Skeleton comes out of the rock, so a tile against a wall calls a dwarf, and anywhere else a kobold.
-- Many at once (`noClaim`): the ceiling it lowers is the only limit, which is the fight Vesh's blue bar is.
local function againstRock(fx, x, y)
    local arena = fx.combat and fx.combat.arena
    if not (arena and arena.tiles) then return false end
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local row = arena.tiles[y + d[2]]
        local cell = row and row[x + d[1]]
        if not cell or not cell.walkable then return true end
    end
    return false
end

-- The AI aims at empty ground beside itself (models/ai.lua's `aiAims`: a summon's mark is a tile no body
-- stands on).
local function openBeside(combat, unit)
    local Combat = require("models.combat")
    local out = {}
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local x, y = unit.x + d[1], unit.y + d[2]
        local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
        local cell = row and row[x]
        if cell and cell.walkable and not Combat.unitAt(combat, x, y) then out[#out + 1] = { x = x, y = y } end
    end
    return out
end

return {
    name = "Call the Lured",
    description = "Calls a skeleton: a Dwarf Skeleton against a wall, a Kobold Skeleton elsewhere. Reserves a fifth of your max mana.",
    flavor = "They came for the gold. They stay for him. Nobody ever leaves the Deeps with what they came for.",
    sprite = "assets/items/ability_call_the_lured.png",
    type = "ability",
    tags = { "dark", "summon" },
    class = "summoner",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 5,
        cooldown = 15,
        support = true,
        reserve = { stat = "mana", percent = 0.2 },
        aiAims = openBeside,
        ai = { priority = "high", act = "cast", label = "the lured answer him",
               whenFn = function(ctx)
                   local n = 0
                   for _, u in ipairs(ctx.combat.units or {}) do
                       if u.alive and u.side == ctx.unit.side and u ~= ctx.unit then n = n + 1 end
                   end
                   return n < 4
               end },
        effect = function(fx)
            local x, y = fx.tx, fx.ty
            if fx.unitAt(x, y) then x, y = fx.openTileNear(x, y) end
            if not x then return end
            local id = againstRock(fx, x, y) and "character_dwarf_skeleton" or "character_kobold_skeleton"
            fx.summon(id, x, y, { noClaim = true })
        end,
    },
}
