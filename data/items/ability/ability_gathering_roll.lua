-- GATHERING ROLL: the Gilded Scarab's roll, made for a person and made of enemies rather than gold. Shove
-- the foe beside you down a lane; it does not stop at the first body it meets -- every body it runs into
-- is gathered into the roll and carried on with it, and when the pile stops, each body in it takes more
-- for every other body gathered. Reviewed 2026-09-25 ("The Coin-Eaters"): a drop has to work on every
-- floor, so the heap became the bodies.
--
-- Fighter stock beside Heave and Leaping Crash. Rift-only: a trophy off the scarab.
local Curve = require("models.curve")

local REACH = 3
local PER_BODY = 4 -- added to every body's blow for each other body in the pile

local function cardinal(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    if math.abs(dx) >= math.abs(dy) then
        if dx == 0 then return 0, 0 end
        return (dx > 0) and 1 or -1, 0
    end
    return 0, (dy > 0) and 1 or -1
end

local function open(fx, x, y)
    local tiles = fx.combat and fx.combat.arena and fx.combat.arena.tiles
    local cell = tiles and tiles[y] and tiles[y][x]
    return cell and cell.walkable or false
end

return {
    name = "Gathering Roll",
    description = "Shoves an adjacent foe 3 tiles, gathering every body it hits; each takes +4 damage per "
        .. "other body in the pile.",
    flavor = "It starts as one problem. By the wall it is everyone's.",
    sprite = "assets/items/ability_gathering_roll.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "fighter",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(9, 19),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local dx, dy = cardinal(fx.user.x, fx.user.y, t.x, t.y)
            if dx == 0 and dy == 0 then return end
            -- The pile, front first: the struck foe, then everything it runs into. Read off the board
            -- before anything moves, so the forecast and the shove agree on who is gathered.
            local pile = { t }
            local x, y = t.x, t.y
            for _ = 1, REACH do
                local nx, ny = x + dx, y + dy
                if not open(fx, nx, ny) then break end
                local body = fx.unitAt(nx, ny)
                if body then pile[#pile + 1] = body end
                x, y = nx, ny
            end
            -- Move the pile, farthest body first, so nobody is walked onto a tile still held.
            for i = #pile, 1, -1 do
                local b = pile[i]
                local ex, ey = b.x, b.y
                for _ = 1, REACH do
                    local nx, ny = ex + dx, ey + dy
                    if not open(fx, nx, ny) then break end
                    local occ = fx.unitAt(nx, ny)
                    if occ and occ ~= b then break end
                    ex, ey = nx, ny
                end
                if ex ~= b.x or ey ~= b.y then
                    fx.teleport(b, ex, ey)
                end
            end
            local ab = fx.item and fx.item.activeAbility
            local base = (ab and type(ab.damage) == "number" and ab.damage) or 0
            local extra = PER_BODY * (#pile - 1)
            for _, b in ipairs(pile) do
                if b.alive then fx.damage(b, { amount = base + extra }) end
            end
        end,
    },
}
