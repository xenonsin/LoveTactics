-- Tests for GIVING GROUND (models/combat.lua: Combat.giveGround and its pure twin
-- Combat.giveGroundTile) -- the step a hit-and-run body takes after it strikes, so the counter its
-- teeth exist to dodge finds nothing in reach.
--
-- The rule these pin: a retreat is not a shove. A shove has one lane and stops dead when that lane is
-- taken; a give-ground exists for the GAP, so any step that opens the gap serves it. Straight back
-- first, then round whatever is standing behind. That distinction is the whole point -- a wolf pack
-- fights shoulder to shoulder, so the tile behind a wolf is very often the next wolf, and under the
-- old shove the pack pinned itself in reach and ate every counter it had bitten to avoid.
--
-- Pure logic, headless. Fixture style mirrors tests/knockback_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

local function arena(cols, rows, blocked)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    for _, b in ipairs(blocked or {}) do
        tiles[b.y][b.x] = { type = "obstacle", moveCost = 99, walkable = false, sightCost = 99 }
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- The wolf's own teeth, out of its own grid: a wolf is armed by being a wolf.
local function fangsOf(u)
    for _, it in ipairs(u.char.inventory) do
        if it and it.id == "weapon_wolf_fangs" then return it end
    end
end

return {
    {
        name = "a give-ground takes the straight lane back when it is open",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit("character_rowan", 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local prey, wolf = c.units[1], c.units[2]

            local moved = Combat.giveGround(c, wolf, prey, 1)
            assert(moved == 1, "it stepped")
            assert(wolf.x == 6 and wolf.y == 3, "straight away from the foe, the way a shove would have")
        end,
    },
    {
        -- The reported bug: the tile behind the wolf is another wolf, so the shove was refused and the
        -- biter stood in reach. A sideways step off an orthogonal neighbour opens the same gap the
        -- straight one does (1 -> 2) on a 4-directional grid, so the lane behind being taken is no
        -- reason to stand still.
        name = "a body behind the retreater sends it round, not nowhere",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit("character_rowan", 4, 3) },
                { unit("character_wolf_grunt", 5, 3), unit("character_wolf_grunt", 6, 3) })
            local prey, wolf, packmate = c.units[1], c.units[2], c.units[3]

            local moved = Combat.giveGround(c, wolf, prey, 1)
            assert(moved == 1, "the packmate at its back does not pin it")
            assert(wolf.x == 5 and (wolf.y == 2 or wolf.y == 4), "it went round -- laterally, off the lane")
            assert(Combat.unitGap(wolf, prey) == 2, "and it is out of reach, which is the whole point")
            assert(packmate.x == 6 and packmate.y == 3, "nobody was shoved to make room")
        end,
    },
    {
        name = "a wall behind the retreater sends it round too",
        fn = function()
            local c = Combat.new(arena(9, 5, { { x = 6, y = 3 } }), { unit("character_rowan", 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local prey, wolf = c.units[1], c.units[2]

            assert(Combat.giveGround(c, wolf, prey, 1) == 1, "impassable terrain is just another blocked lane")
            assert(Combat.unitGap(wolf, prey) == 2, "and the gap opened all the same")
        end,
    },
    {
        -- The one case that still comes to nothing, and must: boxed in on every side that would help.
        -- The wolf is in a dead-end corridor one tile tall, bitten from the open end.
        name = "a retreat with no lane that opens the gap simply does not move",
        fn = function()
            local c = Combat.new(arena(9, 5, { { x = 6, y = 3 }, { x = 5, y = 2 }, { x = 5, y = 4 } }),
                { unit("character_rowan", 4, 3) }, { unit("character_wolf_grunt", 5, 3) })
            local prey, wolf = c.units[1], c.units[2]

            assert(Combat.giveGround(c, wolf, prey, 1) == 0, "walled on three sides, it stays where it bit")
            assert(wolf.x == 5 and wolf.y == 3, "and it certainly does not step TOWARD the foe")
        end,
    },
    {
        -- A give-ground is not a shove, so a blocked one is a failed disengage and not an impact: the
        -- old knockback path logged a collision and (with a live `amount`) would have billed for it.
        name = "a blocked give-ground costs the retreater no health",
        fn = function()
            local c = Combat.new(arena(9, 5, { { x = 6, y = 3 }, { x = 5, y = 2 }, { x = 5, y = 4 } }),
                { unit("character_rowan", 4, 3) }, { unit("character_wolf_grunt", 5, 3) })
            local prey, wolf = c.units[1], c.units[2]
            local before = wolf.char.stats.health.current

            Combat.giveGround(c, wolf, prey, 1)
            assert(wolf.char.stats.health.current == before, "nothing was slammed into, so nothing hurt")
        end,
    },
    {
        name = "an anchored body cannot give ground, and its ghost agrees",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit("character_rowan", 4, 3) },
                { unit("character_wolf_grunt", 5, 3) })
            local prey, wolf = c.units[1], c.units[2]
            Status.apply(c, wolf, "status_root", { applier = prey })
            if not Status.blocksForcedMove(wolf) then return end -- the status is what it is; skip if not

            assert(Combat.giveGround(c, wolf, prey, 1) == 0, "rooted, it holds the tile it bit from")
            local rx, ry = Combat.giveGroundTile(c, wolf, prey, 1)
            assert(rx == 5 and ry == 3, "and the preview must not promise a step the live move refuses")
        end,
    },
    {
        -- Combat.giveGroundTile is what the hover preview weighs a counter against
        -- (Combat.previewCounters), so it has to walk the same lanes the live step walks. A ghost that
        -- stopped dead where the shove used to would promise exactly the counter the step avoids.
        name = "the give-ground preview rests on the tile the live step lands on",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit("character_rowan", 4, 3) },
                { unit("character_wolf_grunt", 5, 3), unit("character_wolf_grunt", 6, 3) })
            local prey, wolf = c.units[1], c.units[2]

            local rx, ry = Combat.giveGroundTile(c, wolf, prey, 1)
            assert(wolf.x == 5 and wolf.y == 3, "the ghost moved nothing")
            Combat.giveGround(c, wolf, prey, 1)
            assert(wolf.x == rx and wolf.y == ry, "and it named the tile the wolf actually took")
        end,
    },
    {
        -- End to end, through the teeth: the bite's own effect calls fx.retreat, and this is the shape
        -- the bug was reported in -- a wolf biting with a packmate directly behind it.
        name = "a wolf hemmed in behind still leaves the square it bit from",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit("character_rowan", 4, 3) },
                { unit("character_wolf_grunt", 5, 3), unit("character_wolf_grunt", 6, 3) })
            local prey, wolf = c.units[1], c.units[2]
            local fangs = fangsOf(wolf)
            assert(fangs, "the wolf bites with its fangs")

            openTurn(c, wolf)
            local result = Combat.strikeWith(c, wolf, fangs, prey.x, prey.y)
            assert(result.damageDealt > 0, "the wolf bites")
            assert(Combat.unitGap(wolf, prey) == 2, "and is gone before the jaws can snap back")
        end,
    },
    {
        -- Combat.answerStrike's half of the same contract: the teeth give ground whichever way round
        -- the exchange began, so a countering wolf does not stand in reach to be worked over either.
        name = "a wolf that ANSWERS a blow gives ground round a blocked lane too",
        fn = function()
            local c = Combat.new(arena(9, 5), { unit("character_rowan", 4, 3) },
                { unit("character_wolf_grunt", 5, 3), unit("character_wolf_grunt", 6, 3) })
            local prey, wolf = c.units[1], c.units[2]
            local fangs = fangsOf(wolf)

            Combat.answerStrike(c, wolf, prey, fangs)
            assert(Combat.unitGap(wolf, prey) == 2, "it bit back and it is gone")
        end,
    },
    {
        -- Harrying Strike and Vanishing Strike are the player-side stock of the same doctrine, and both
        -- handed fx.retreat the USER where the helper wants the body being backed away FROM: a step
        -- away from yourself is a step of zero, so neither ability moved its striker an inch.
        name = "the hit-and-run abilities step their striker off the square it swung from",
        fn = function()
            for _, id in ipairs({ "ability_harrying_strike", "ability_vanishing_strike" }) do
                local rogue = Character.instantiate("character_rogue")
                for i = 1, Character.MAX_INVENTORY do rogue.inventory[i] = nil end
                local ability = Item.instantiate(id)
                rogue.inventory[1] = ability
                local c = Combat.new(arena(9, 5), { unit(rogue, 4, 3) },
                    { unit("character_bandit", 5, 3) })
                local striker, foe = c.units[1], c.units[2]

                openTurn(c, striker)
                assert(Combat.useItem(c, striker, ability, foe.x, foe.y), id .. " lands")
                assert(Combat.unitGap(striker, foe) == 2, id .. " slips its striker back out of reach")
            end
        end,
    },
}
