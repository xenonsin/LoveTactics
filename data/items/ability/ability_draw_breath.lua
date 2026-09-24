-- DRAW BREATH: the beast's inhale (data/items/ability/ability_the_breath.lua), rebuilt for a person. Lifted
-- off Gula; settled on review 2026-09-23.
--
-- Winds up for a turn with the band painted on the board, then drags every FOE in it to you. A foe that
-- arrives at your side already beaten -- a quarter of its health or less -- is swallowed whole: gone, with
-- no corpse left behind. Never a boss (Combat.devour refuses one, which is Coup de Grace's rule).
--
-- PULLING IS LUST'S VERB, AND THIS IS NOT LUST'S. Lust's pulls are about WHERE you stand; this one is about
-- the finish -- it is a hunt's last stroke, taking the wounded out of a line they were hiding behind. A
-- body that is not beaten yet is dragged and left standing at your feet, which is its own decision to
-- have made. A rooted body is anchored and does not come (Combat.pull), and a body two tiles wide is too
-- big to drag at all.
--
-- Unlike hers it takes only foes, and it is narrower: three wide, three deep, off the face you turn to.
-- A general's find: `unstocked`, the druid's shelf (the one that draws the wild toward it).
local Curve = require("models.curve")

local DEPTH = 3
local SWALLOW = 0.25

local function facing(unit, tx, ty)
    local dx, dy = tx - unit.x, ty - unit.y
    if math.abs(dx) >= math.abs(dy) then
        if dx == 0 then return 0, 0 end
        return (dx > 0) and 1 or -1, 0
    end
    return 0, (dy > 0) and 1 or -1
end

local function band(unit, tx, ty)
    local dx, dy = facing(unit, tx, ty)
    local out = {}
    if dx == 0 and dy == 0 then return out end
    local px, py = -dy, dx
    for i = 1, DEPTH do
        for j = -1, 1 do
            out[#out + 1] = { x = unit.x + dx * i + px * j, y = unit.y + dy * i + py * j }
        end
    end
    return out
end

return {
    name = "Draw Breath",
    description = "Winds up, then drags every foe in a band toward you. A foe at 25% health or less that reaches you is swallowed whole.",
    flavor = "The glade leans toward you. You have not decided yet what that makes you.",
    sprite = "assets/items/ability_draw_breath.png",
    type = "ability",
    tags = { "wind", "physical" },
    class = "druid",
    unlockLevel = 2,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = DEPTH,
        speed = 4,
        windup = 3,
        cooldown = 15,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(7, 17),
        aoe = {
            cells = function(_, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                return band(unit, tx, ty)
            end,
        },
        effect = function(fx)
            local u = fx.user
            local caught = {}
            for _, t in ipairs(fx.aoeUnits()) do
                if t ~= u and t.alive and t.side ~= u.side then caught[#caught + 1] = t end
            end
            table.sort(caught, function(a, b)
                local da = math.abs(a.x - u.x) + math.abs(a.y - u.y)
                local db = math.abs(b.x - u.x) + math.abs(b.y - u.y)
                if da ~= db then return da < db end
                if a.y ~= b.y then return a.y < b.y end
                return a.x < b.x
            end)
            -- Drag, swallow, THEN bite -- the beast's order, for the beast's reason: a beaten body bitten
            -- first dies where it stands and is never swallowed.
            for _, t in ipairs(caught) do
                if t.alive and (t.w or 1) == 1 and (t.h or 1) == 1 then fx.pull(t) end
            end
            for _, t in ipairs(caught) do
                local th = t.char.stats.health
                local beaten = th.max and th.max > 0 and th.current <= th.max * SWALLOW
                if t.alive and beaten and math.abs(t.x - u.x) + math.abs(t.y - u.y) == 1 then
                    fx.devour(t, { weakFoe = SWALLOW })
                end
            end
            for _, t in ipairs(caught) do
                if t.alive and not t.devoured then fx.damage(t) end
            end
        end,
    },
}
