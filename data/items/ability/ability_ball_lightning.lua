-- BALL LIGHTNING: become the bolt ("Fire, Lightning, and Dirty Thunder", round 2, 2026-09-28) -- one of the three
-- things the Thunderhead drops, off its fusion: two bodies become one moving storm. Aimed along a row or a column
-- (`straight`) at an empty tile up to 5 away, the caster goes THROUGH every body between, striking each with
-- lightning, friend or foe, and lands on the tile. A dash that is also an attack -- and whatever stands in the line,
-- your own side included, is in it. A Battlemage's: the swing is the spell, and so is the walk.
local Curve = require("models.curve")

local function step(a, b)
    if b > a then return 1 elseif b < a then return -1 end
    return 0
end

-- The tiles from the caster to the aimed one, the aimed tile last.
local function path(unit, tx, ty)
    local out = {}
    if not unit or (unit.x ~= tx and unit.y ~= ty) then return out end
    local dx, dy = step(unit.x, tx), step(unit.y, ty)
    local x, y = unit.x, unit.y
    while x ~= tx or y ~= ty do
        x, y = x + dx, y + dy
        out[#out + 1] = { x = x, y = y }
    end
    return out
end

return {
    name = "Ball Lightning",
    description = "Dash in a straight line up to 5 tiles to an empty one, through bodies, striking each with lightning.",
    flavor = "It does not go round. It has never once gone round.",
    sprite = "assets/items/ability_ball_lightning.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "battlemage",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 5,
        straight = true,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        damage = Curve.ramp(11, 21), -- the slot-8 ability target (tests/balance_spec.lua)
        -- The line itself: every tile the caster passes, so the forecast shows who is in the way.
        aoe = { cells = function(_, tx, ty, unit) return path(unit, tx, ty) end },
        effect = function(fx)
            local cells = path(fx.user, fx.tx, fx.ty)
            if #cells == 0 then return end
            local struck = {}
            for _, c in ipairs(cells) do
                local body = fx.unitAt(c.x, c.y)
                if body and body ~= fx.user and body.alive then struck[#struck + 1] = body end
            end
            fx.teleportUser(fx.tx, fx.ty)
            for _, b in ipairs(struck) do
                if b.alive then fx.damage(b) end
            end
        end,
    },
}
