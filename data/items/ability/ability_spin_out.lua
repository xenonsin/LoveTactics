-- SPIN OUT: the Goblin Fanatic's ball and chain, and the drop off it. Round 2 (2026-09-26, "The Goblins of
-- Wrath"): Ball and Chain was denied ("Clear Out is too similar and better"), and Spin Out picked over Madcap
-- Brew.
--
-- PICK A DIRECTION, AND NEXT TURN YOU SPIN THREE TILES ALONG IT, striking every body beside the path --
-- ALLIES INCLUDED. The wind-up (`windup`, one turn) is the telegraph: the lane is drawn for both sides while it
-- winds, which is what makes a Fanatic readable -- step out of the line, or leave goblins standing in it.
--
-- NOT A BETTER CLEAR OUT. Clear Out spins on the spot, now, and cuts foes only. This one waits, moves you,
-- and cannot tell a friend from a foe: it is a setup, and it punishes a tight formation on either side.
--
-- The spin stops at the first thing it cannot enter -- a body, a wall, lava. A bearer that is UNSTEERED (the
-- Fanatic's own organ, trait_unsteered) does not stop at lava: it goes in, and it is gone.
local Curve = require("models.curve")

local LENGTH = 3

return {
    name = "Spin Out",
    description = "Winds up for a turn, then spins 3 tiles in a line, striking every body beside the path, allies included.",
    flavor = "Nobody aims it. Nobody has ever aimed it. The trick is to be somewhere else.",
    sprite = "assets/items/ability_spin_out.png",
    type = "ability",
    tags = { "impact", "physical", "melee" },
    class = "barbarian",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1, -- a neighbour: it sets the direction
        speed = 4,
        windup = 5, -- one turn: the lane is committed and marked
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(10, 24),
        aoe = { shape = "line", length = LENGTH },
        ai = { priority = "high", act = "cast" },
        aiAims = function(_, unit)
            return { { x = unit.x + 1, y = unit.y }, { x = unit.x - 1, y = unit.y },
                     { x = unit.x, y = unit.y + 1 }, { x = unit.x, y = unit.y - 1 } }
        end,
        effect = function(fx)
            local user = fx.user
            local tiles = fx.combat and fx.combat.arena and fx.combat.arena.tiles
            local unsteered = require("models.trait").flag(user, "unsteered")
            local path = { { x = user.x, y = user.y } }
            local stop, drowned = nil, false
            for _, c in ipairs(fx.aoeCells() or {}) do
                local cell = tiles and tiles[c.y] and tiles[c.y][c.x]
                if not cell then break end
                if cell.type == "lava" and unsteered then drowned = true break end
                if not cell.walkable or fx.unitAt(c.x, c.y) then break end
                stop = c
                path[#path + 1] = c
            end
            if stop then fx.teleportUser(stop.x, stop.y, { glide = true }) end
            local struck = {}
            for _, c in ipairs(path) do
                for _, u in ipairs(fx.unitsNear(c.x, c.y, 1)) do
                    if u ~= user and u.alive and not struck[u] then
                        struck[u] = true
                        fx.damage(u)
                    end
                end
            end
            if drowned and user.alive then
                fx.log("action", string.format("%s spins straight into the lava.",
                    (user.char and user.char.name) or "It"), user)
                local hp = user.char and user.char.stats and user.char.stats.health
                if hp and (hp.current or 0) > 0 then fx.flatDamage(user, hp.current, { "fire" }) end
            end
        end,
    },
}
