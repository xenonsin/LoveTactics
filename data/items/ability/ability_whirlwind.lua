-- WHIRLWIND: the Whirl Elemental's own trick, and the one cast in the game that does not let its caster
-- choose where it goes.
--
-- ON ACTIVATION THE WIND PICKS A TILE. Any tile along the eight straight lines out of the caster, up to
-- four out, stopping at the first wall, piece of furniture or ground a body cannot stand on -- and one of
-- them, drawn from the battle's own sequence (fx.random), is where the caster is going. It travels there
-- in a straight line OVER everyone in the way and cuts every body it passes, friend or foe. If the tile
-- it lands on is taken, whoever stands there is cut too and thrown one tile in a random direction; a
-- throw that hits something is a collision, and hurts as one (Combat.knockback). When the tile will not
-- clear, the caster comes down on the last open tile short of it.
--
-- THE FOOTPRINT IS THE TELL. Every tile the draw could land on is painted as the ability's area
-- (`aoe.cells`), so what the board shows before the cast is the honest answer to "where can this go":
-- a star, clipped by the walls. A company reads which of its bodies stand on the rays, not which one
-- will be hit, and that is the most a random blade can ever promise.
--
-- A FLIGHT, NOT A WALK. The caster never touches the ground it crosses -- the rush is over the heads in
-- the lane -- so it springs only the tile it lands on, as a leap does (Combat.teleportUnit, with `glide`
-- so it is seen crossing rather than vanishing). That is also why bodies in the lane do not stop it.
--
-- A BARBARIAN'S, BECAUSE A BARBARIAN IS THE ONE WHO WANTS IT. Every other house prices where it stands;
-- the Barbarian is the house that has stopped caring, and a spinning rush into wherever the wind puts
-- you is that house's temper exactly. `unstocked`: a trophy, off the Whirl Elemental and nowhere else,
-- and no counter deals one in either direction (tests/discovery_spec.lua names it).
--
-- THE ELEMENTAL DOES NOT CARRY THIS FILE, it carries weapon_gyre -- creature kit is natural weapons only
-- (tests/bestiary_spec.lua), so the body's own copy is a natural weapon that borrows this effect whole,
-- the arrangement Into the Green has with Greenstep.
local Curve = require("models.curve")

local REACH = 4
local RAYS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

local function sign(n) return (n > 0 and 1) or (n < 0 and -1) or 0 end

-- Ground the rush may cross or come down on: on the board, standable, and not under a wall or a prop.
-- Bodies are NOT asked about -- the wind goes over them.
local function ground(combat, x, y)
    local Combat = require("models.combat")
    local row = combat.arena and combat.arena.tiles and combat.arena.tiles[y]
    local cell = row and row[x]
    return cell ~= nil and cell.walkable and not Combat.objectBlocksAt(combat, x, y)
end

return {
    name = "Whirlwind",
    description = "Rushes to a random tile up to four away, cutting all it passes; a body on that tile is "
        .. "thrown one tile.",
    flavor = "It does not go where it is pointed. Nothing in that building has gone where it was pointed "
        .. "for three hundred years.",
    sprite = "assets/items/ability_whirlwind.png",
    type = "ability",
    tags = { "wind", "slash", "physical" },
    class = "barbarian", -- the SHELF it is graded against, and never a counter that deals it: see above
    unstocked = true,
    unlockLevel = 4,
    activeAbility = {
        target = "self",
        range = 0,
        support = false, -- a self-cast that cuts: the rays paint red, not green
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(9, 19), -- per body in the lane; slot 4's target (Balance), the random landing is the discount
        aoe = {
            -- The eight rays out of the aim cell (the caster's own tile, or the tile the planner would
            -- have it walk to first), each cut at the first tile it cannot cross.
            cells = function(combat, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                local out = {}
                for _, r in ipairs(RAYS) do
                    for i = 1, REACH do
                        local x, y = tx + r[1] * i, ty + r[2] * i
                        if not ground(combat, x, y) then break end
                        out[#out + 1] = { x = x, y = y }
                    end
                end
                return out
            end,
        },
        ai = { priority = "high", act = "attack",
               when = { subject = "any_foe", test = "within", value = REACH } },
        effect = function(fx)
            local cells = fx.aoeCells()
            if #cells == 0 then return end -- hemmed in on all eight sides: nowhere for the wind to go
            local pick = cells[fx.random(#cells)]
            local ox, oy = fx.user.x, fx.user.y
            local dx, dy = sign(pick.x - ox), sign(pick.y - oy)
            local dist = math.max(math.abs(pick.x - ox), math.abs(pick.y - oy))
            -- The lane, landing tile included. A pick on the caster's own tile only happens in the
            -- inventory tooltip's board-less dry run, and reading it as a one-tile lane is what lets the
            -- tooltip quote the cut at all.
            local lane = {}
            for i = math.min(1, dist), dist do lane[#lane + 1] = { x = ox + dx * i, y = oy + dy * i } end

            local seen = {}
            for _, c in ipairs(lane) do
                local u = fx.unitAt(c.x, c.y)
                if u and u ~= fx.user and u.alive and not seen[u] then
                    seen[u] = true
                    fx.damage(u)
                end
            end

            -- Whoever is standing where it means to come down is thrown one tile, any of the four ways.
            local occupant = fx.unitAt(pick.x, pick.y)
            if occupant and occupant ~= fx.user and occupant.alive then
                local r = RAYS[fx.random(4)]
                fx.knockback(occupant, 1, { dest = { x = occupant.x + r[1], y = occupant.y + r[2] } })
            end

            -- Come down on the pick if it cleared, else on the last open tile short of it. Every tile in
            -- the lane is ground (the rays stop at anything that is not), so "open" is only "unoccupied".
            for i = #lane, 1, -1 do
                local c = lane[i]
                if c.x == ox and c.y == oy then return end
                local u = fx.unitAt(c.x, c.y)
                if not u or u == fx.user then
                    fx.teleportUser(c.x, c.y, { glide = true })
                    return
                end
            end
        end,
    },
}
