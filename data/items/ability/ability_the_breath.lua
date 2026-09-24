-- THE BREATH: the beast draws breath, and everything in front of it comes to it. Kirby's inhale, and the
-- second form's answer to being too slow to walk to its food (settled on review 2026-09-23).
--
-- A WIND-UP, BECAUSE THE TELEGRAPH IS THE WHOLE COUNTERPLAY. The band is committed a turn early and
-- painted on the board (`windup`, the Gore's rule), so the answer is to read it: leave the band, stand
-- behind something big, or stand Rooted on purpose -- a rooted body is anchored and does not come
-- (Combat.pull), which makes the web that catches you on every forest board the safest tile in the glade.
-- A body two tiles wide is too big to drag and is left where it stands.
--
-- THREE THINGS HAPPEN, IN THIS ORDER, and the order is the design:
--   1. everything in the band is dragged to her, nearest first, so the far ones fetch up behind the near
--      ones rather than through them. Her OWN beasts come too: the Breath is also how the food arrives;
--   2. a foe that reaches her mouth already beaten -- at 30% of its health or less -- is swallowed
--      whole (Combat.devour's `weakFoe` door), and she takes it as she would anything she ate;
--   3. every foe still standing in the band takes the bite of the inhale -- small, and the part the
--      forecast can see. It comes LAST on purpose: bitten first, a beaten body dies where it stands and
--      the swallow the whole ability is for never happens.
--
-- WHY A BAND AND NOT A CONE. A cone widens from a point, and it would reach five wide at the far end --
-- a net, not a breath. The band is as wide as her body and a tile past each side (three, at one tile),
-- four deep, off whichever face she turns to. Measured off the footprint rather than the anchor, so a
-- wider body drawn later breathes from its whole face.
local Curve = require("models.curve")

local DEPTH = 4
local SWALLOW = 0.30

-- Which face of the body `unit` the aimed tile lies off, as a unit step.
local function facing(unit, tx, ty)
    local w, h = unit.w or 1, unit.h or 1
    local dx = (tx < unit.x and -1) or (tx > unit.x + w - 1 and 1) or 0
    local dy = (ty < unit.y and -1) or (ty > unit.y + h - 1 and 1) or 0
    if dx ~= 0 and dy ~= 0 then
        -- A diagonal aim: take the axis it is further along.
        local ox = dx > 0 and tx - (unit.x + w - 1) or unit.x - tx
        local oy = dy > 0 and ty - (unit.y + h - 1) or unit.y - ty
        if ox >= oy then dy = 0 else dx = 0 end
    end
    return dx, dy
end

local function band(unit, tx, ty)
    local w, h = unit.w or 1, unit.h or 1
    local dx, dy = facing(unit, tx, ty)
    local out = {}
    if dx ~= 0 then
        local x0 = dx > 0 and unit.x + w or unit.x - 1
        for i = 0, DEPTH - 1 do
            for y = unit.y - 1, unit.y + h do out[#out + 1] = { x = x0 + dx * i, y = y } end
        end
    elseif dy ~= 0 then
        local y0 = dy > 0 and unit.y + h or unit.y - 1
        for i = 0, DEPTH - 1 do
            for x = unit.x - 1, unit.x + w do out[#out + 1] = { x = x, y = y0 + dy * i } end
        end
    end
    return out
end

-- The footprint-aware gap from `unit` to a one-tile body (Combat.cellGap's arithmetic).
local function gap(unit, t)
    local w, h = unit.w or 1, unit.h or 1
    local gx = math.max(unit.x - t.x, t.x - (unit.x + w - 1), 0)
    local gy = math.max(unit.y - t.y, t.y - (unit.y + h - 1), 0)
    return gx + gy
end

return {
    name = "The Breath",
    description = "Winds up, then drags everything in a band toward her. A foe at 30% health or less that reaches her is swallowed whole.",
    flavor = "The whole glade leans toward her, and then it is inside.",
    sprite = "assets/items/ability_the_breath.png",
    type = "ability",
    class = "creature",
    tags = { "wind", "physical" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = DEPTH,
        speed = 4,
        windup = 3, -- the band is committed here, and everyone gets to read it
        cooldown = 10,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(4, 14),
        aoe = {
            cells = function(_, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                return band(unit, tx, ty)
            end,
        },
        -- Worth drawing breath for two bodies at once, or for one that would go down whole.
        ai = { priority = "high", act = "attack", label = "two foes, or a beaten one, in reach of the breath",
               whenFn = function(ctx)
                   local Combat = require("models.combat")
                   local near, weak = 0, false
                   for _, f in ipairs(ctx.combat.units) do
                       if f.alive and f.side ~= ctx.unit.side and Combat.unitGap(ctx.unit, f) <= DEPTH then
                           near = near + 1
                           local hp = f.char.stats.health
                           if hp.max and hp.max > 0 and hp.current <= hp.max * SWALLOW then weak = true end
                       end
                   end
                   return near >= 2 or weak
               end },
        effect = function(fx)
            local u = fx.user
            local caught = {}
            for _, t in ipairs(fx.aoeUnits()) do
                if t ~= u and t.alive then caught[#caught + 1] = t end
            end
            table.sort(caught, function(a, b)
                local ga, gb = gap(u, a), gap(u, b)
                if ga ~= gb then return ga < gb end
                if a.y ~= b.y then return a.y < b.y end
                return a.x < b.x
            end)
            for _, t in ipairs(caught) do
                if t.alive and (t.w or 1) == 1 and (t.h or 1) == 1 then fx.pull(t) end
            end
            local hp = u.char and u.char.stats and u.char.stats.health
            local meal = math.floor(((hp and hp.max) or 0) * 0.10 + 0.5)
            for _, t in ipairs(caught) do
                local th = t.char.stats.health
                local beaten = th.max and th.max > 0 and th.current <= th.max * SWALLOW
                if t.alive and t.side ~= u.side and beaten and gap(u, t) == 1
                    and fx.devour(t, { weakFoe = SWALLOW }) then
                    if meal > 0 then fx.heal(u, meal) end
                    fx.applyStatus(u, "status_gorged")
                end
            end
            for _, t in ipairs(caught) do
                if t.alive and t.side ~= u.side and not t.devoured then fx.damage(t) end
            end
        end,
    },
}
