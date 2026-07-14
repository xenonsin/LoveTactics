-- Tests for the trap system (models/trap.lua) and its combat hooks: pass-through triggering as a
-- unit walks over a tile, own-side immunity, damaging/destroying a revealed trap, detector-gated
-- visibility, status-delivering traps, and both placement paths (authored arena + fx.placeTrap).
-- Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Trap = require("models.trap")
local Status = require("models.status")

local function arena(cols, rows, traps)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" }, traps = traps }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    -- Strip the innate signature relic (see tests/innate_spec.lua): the archer's would field a wolf
    -- (an extra unit) and its center cell would skew grid-position math these fixtures rely on.
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

return {
    {
        name = "a unit pathing OVER an enemy trap triggers it (not just the landing tile)",
        fn = function()
            -- Archer (movement 4, less 1 for its leather armor = 3) walks (1,1)->(1,4),
            -- crossing a spike trap parked at (1,3).
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, {})
            Trap.place(c, 1, 3, "spike_trap", "enemy")
            local archer = c.units[1]
            local hp0 = archer.char.stats.health.current
            openTurn(c, archer)

            assert(Combat.moveUnit(c, archer, 1, 4), "the 3-cost move succeeds")
            assert(archer.x == 1 and archer.y == 4, "the unit still reaches its destination")
            assert(archer.char.stats.health.current < hp0, "crossing the trap dealt damage")
            assert(Trap.at(c, 1, 3) == nil, "the one-shot spike trap is spent after triggering")
        end,
    },
    {
        name = "a unit killed by a trap en route stops on the tile it fell on",
        fn = function()
            -- One hit point left: the spike trap at (1,3) finishes the archer halfway to (1,4).
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, {})
            Trap.place(c, 1, 3, "spike_trap", "enemy")
            local archer = c.units[1]
            archer.char.stats.health.current = 1
            openTurn(c, archer)

            assert(Combat.moveUnit(c, archer, 1, 4), "the move is legal (it is the walk that kills)")
            assert(not archer.alive, "the trap killed the archer")
            assert(archer.x == 1 and archer.y == 3,
                "it lies on the trap, not at the destination (got " .. archer.x .. "," .. archer.y .. ")")
        end,
    },
    {
        name = "a unit does not trigger its own side's trap",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, {})
            Trap.place(c, 1, 3, "spike_trap", "party") -- friendly trap
            local archer = c.units[1]
            local hp0 = archer.char.stats.health.current
            openTurn(c, archer)

            assert(Combat.moveUnit(c, archer, 1, 4), "move over the friendly trap")
            assert(archer.char.stats.health.current == hp0, "no damage from a same-side trap")
            assert(Trap.at(c, 1, 3), "the friendly trap is untouched")
        end,
    },
    {
        name = "a snare trap applies root to the victim instead of dealing damage",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, {})
            Trap.place(c, 1, 3, "snare_trap", "enemy")
            local archer = c.units[1]
            local hp0 = archer.char.stats.health.current
            openTurn(c, archer)

            assert(Combat.moveUnit(c, archer, 1, 4), "walk onto/over the snare")
            assert(archer.char.stats.health.current == hp0, "a snare deals no damage")
            assert(Status.has(archer, "root"), "the snare rooted the victim")
        end,
    },
    {
        name = "damaging a revealed trap destroys it and runs onDestroy",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            Trap.defs.test_boom = { name = "Boom", health = 5,
                onDestroy = function(ctx) ctx.combat._boomed = true end }
            local trap = Trap.place(c, 4, 4, "test_boom", "enemy")

            assert(Trap.damage(c, trap, 2) == 2 and trap.alive, "a glancing hit leaves it standing (3 HP)")
            Trap.damage(c, trap, 3)
            assert(not trap.alive and trap.health == 0, "reaching 0 HP destroys the trap")
            assert(c._boomed, "onDestroy fired")
            assert(Trap.at(c, 4, 4) == nil, "a destroyed trap is gone from the tile")

            Trap.defs.test_boom = nil -- don't leak the fixture
        end,
    },
    {
        name = "a trap is hidden from opponents until a detector is within range",
        fn = function()
            -- Enemy trap at (4,4). A knight carrying a Trap Sense Charm (detectRadius 2) reveals it
            -- only when close enough; the owning side always sees its own trap.
            local scout = Character.instantiate("knight")
            scout.inventory = {} -- controlled grid: just the detector (no starting gear, no innate relic)
            assert(Character.addItem(scout, Item.instantiate("trap_sense")), "equip the detector")

            local c = Combat.new(arena(8, 8), { unit(scout, 4, 7) }, {})
            Trap.place(c, 4, 4, "spike_trap", "enemy")
            local trap = c.traps[1]

            assert(Trap.visibleTo(c, trap, "enemy"), "the owner always sees its own trap")
            assert(not Trap.visibleTo(c, trap, "party"), "3 tiles away (>2) it stays hidden")

            c.units[1].y = 6 -- step to (4,6): now 2 tiles from the trap
            assert(Trap.visibleTo(c, trap, "party"), "within detectRadius the trap is revealed")
        end,
    },
    {
        name = "a trap cannot be placed on an impassable tile (Trap.place refuses)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            c.arena.tiles[3][3].walkable = false -- turn (3,3) into a solid obstacle
            assert(Trap.place(c, 3, 3, "spike_trap", "enemy") == nil, "placement on a wall is refused")
            assert(Trap.at(c, 3, 3) == nil, "no trap was created on the impassable tile")
            assert(Trap.place(c, 4, 4, "spike_trap", "enemy"), "a walkable tile still accepts a trap")
        end,
    },
    {
        name = "the trap-placement ability refuses an impassable target without spending the turn",
        fn = function()
            -- Knight (mana 20) with the Spike Trap ability aims at a solid obstacle in range: the
            -- cast is rejected before any cost is paid and the turn stays open.
            local caster = Character.instantiate("knight")
            caster.inventory = {} -- controlled grid: only the trap ability (no innate relic or starting gear)
    Character.addItem(caster, Item.instantiate("ability_spike_trap"))
            local c = Combat.new(arena(8, 8), { unit(caster, 3, 3) }, {})
            c.arena.tiles[5][3].walkable = false -- block the target cell (tx=3, ty=5) -> tiles[y][x]
            local u = c.units[1]
            local ability = u.char.inventory[#u.char.inventory]
            openTurn(c, u)

            local mana0 = Combat.resource(u.char, "mana")
            local ok, reason = Combat.useItem(c, u, ability, 3, 5)
            assert(not ok and reason == "blocked tile", "placing on an obstacle is refused: " .. tostring(reason))
            assert(#c.traps == 0, "no trap was placed")
            assert(Combat.resource(u.char, "mana") == mana0, "the mana cost was not spent")
            assert(c.turn ~= nil, "the turn did not end on the rejected cast")
        end,
    },
    {
        name = "a trap cannot be placed on a tile a unit occupies (Trap.place refuses)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, { unit("bandit", 5, 5) })
            assert(Trap.place(c, 4, 4, "spike_trap", "enemy") == nil, "can't place under the knight")
            assert(Trap.place(c, 5, 5, "spike_trap", "party") == nil, "can't place under the bandit")
            assert(Trap.at(c, 4, 4) == nil and Trap.at(c, 5, 5) == nil, "no trap on an occupied tile")
            assert(Trap.place(c, 4, 5, "spike_trap", "enemy"), "an empty tile still accepts a trap")
        end,
    },
    {
        name = "the trap-placement ability refuses a tile with a character on it (no turn spent)",
        fn = function()
            -- Knight with the Spike Trap ability aims at the bandit's own tile (2 away, in range 3):
            -- rejected before any cost, since a trap can't be summoned onto an occupied tile.
            local caster = Character.instantiate("knight")
            caster.inventory = {} -- controlled grid: only the trap ability (no innate relic or starting gear)
    Character.addItem(caster, Item.instantiate("ability_spike_trap"))
            local c = Combat.new(arena(8, 8), { unit(caster, 3, 3) }, { unit("bandit", 3, 5) })
            local u = c.units[1]
            local ability = u.char.inventory[#u.char.inventory]
            openTurn(c, u)

            local mana0 = Combat.resource(u.char, "mana")
            local ok, reason = Combat.useItem(c, u, ability, 3, 5)
            assert(not ok and reason == "occupied tile", "aiming at a unit is refused: " .. tostring(reason))
            assert(#c.traps == 0, "no trap was placed")
            assert(Combat.resource(u.char, "mana") == mana0, "the mana cost was not spent")
            assert(c.turn ~= nil, "the turn did not end on the rejected cast")
        end,
    },
    {
        name = "traps are placed both by authored arena data and by fx.placeTrap (the summon ability)",
        fn = function()
            -- Authored: arena.traps is consumed by Combat.new.
            local authored = arena(8, 8, { { id = "spike_trap", x = 5, y = 5, side = "enemy" } })
            local c = Combat.new(authored, { unit("knight", 1, 1) }, {})
            assert(#c.traps == 1 and c.traps[1].x == 5 and c.traps[1].side == "enemy",
                "the authored trap is loaded into combat")

            -- Summoned: a unit uses the Spike Trap ability (target = "tile") on an empty cell.
            local caster = Character.instantiate("knight") -- mana 20 >= ability cost 8
            caster.inventory = {} -- controlled grid: only the trap ability (no innate relic or starting gear)
    Character.addItem(caster, Item.instantiate("ability_spike_trap"))
            local c2 = Combat.new(arena(8, 8), { unit(caster, 3, 3) }, {})
            local u = c2.units[1]
            local ability = u.char.inventory[#u.char.inventory]
            assert(ability.id == "ability_spike_trap", "the caster holds the trap ability")
            openTurn(c2, u)

            local ok = Combat.useItem(c2, u, ability, 3, 5) -- place 2 tiles away (range 3)
            assert(ok, "placing a trap on a tile in range succeeds")
            assert(#c2.traps == 1, "fx.placeTrap added a trap to combat")
            local placed = Trap.at(c2, 3, 5)
            assert(placed and placed.side == "party", "the placed trap is owned by the caster's side")
        end,
    },
}
