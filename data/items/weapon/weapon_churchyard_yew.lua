-- The Churchyard Yew: a longbow cut from the Hamadryad's own tree -- yew is the longbow wood, and every
-- churchyard grows one -- and it hits hardest against a body with something at its back.
--
-- A LONGBOW BY CONTRACT (docs/weapons.md): the draw winds up, it looses from five, `minRange` 2,
-- `requiresSight`, two hands. Its extra over the base is where the TARGET stands: a foe with a plant, a
-- wall or impassable ground beside it takes half as much again -- pinned to the wood. It was drafted as
-- a range bonus while its BEARER stood beside a wall; a fight board has few walls and the field bonus
-- that would carry a positional range is banked per turn, so the idea was turned round to the side of
-- the shot that can be read at the moment it lands.
--
-- WHICH PAIRS IT WITH EVERYTHING THE GROVE GROWS. Quickset puts a hedge behind a foe; Seedfall puts a
-- sapling there; the keep's own blockers are the rest. `unstocked`: a trophy, off the Hamadryad and
-- nowhere else (tests/discovery_spec.lua names it).
local Curve = require("models.curve")

return {
    name = "Churchyard Yew",
    description = "Channeled. Half again as hard against a foe with a plant, wall or blocker beside it.",
    flavor = "The yew outlives the church it was planted beside. It was here before the keep, and it knows where everybody stood.",
    sprite = "assets/items/weapon_churchyard_yew.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2,
    class = "hunter",
    unstocked = true,
    unlockLevel = 5,
    activeAbility = {
        target = "enemy",
        range = 5,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        windup = 2,
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(14, 26),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local Grove = require("models.grove")
            local Wall = require("models.wall")
            local combat = fx.combat
            local pinned = Grove.besidePlant(combat, t.x, t.y)
            if not pinned then
                local tiles = combat.arena and combat.arena.tiles
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if not (dx == 0 and dy == 0) then
                            local x, y = t.x + dx, t.y + dy
                            local cell = tiles and tiles[y] and tiles[y][x]
                            if (cell and not cell.walkable) or Wall.blocksAt(combat, x, y) then pinned = true end
                        end
                    end
                end
            end
            if pinned then
                fx.damage(t, { amount = math.floor((fx.amount or 0) * 1.5) })
            else
                fx.damage(t)
            end
        end,
    },
}
