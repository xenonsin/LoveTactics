-- Shared combat fixtures for the headless specs.
--
-- Nearly every behavioural spec needs the same two things: a featureless board to fight on, and a
-- unit standing on it carrying exactly the items under test. Before this module 63 spec files each
-- carried their own copy of `arena()` and ~53 their own unit builder, all subtly diverged (some set
-- `sightCost`, some did not; some stripped a character's innate relic, some did not), which made a
-- test's real baseline hard to read and a new item test expensive to start.
--
-- This is not a test framework -- tests/runner.lua stays the whole of that. It is just the fixtures,
-- in one place, with the variation that mattered turned into named options.
--
-- Not itself a spec: the runner only globs tests/*_spec.lua, so this file is never run as one.
--
-- Named `Fixture` rather than `Arena` on purpose: models/arena.lua is the game's real board builder
-- and eight specs already bind `Arena` to it. `Fixture.new` is a scratch board for a test to fight
-- on; `Arena.build` is the thing the game ships. Keeping the names apart keeps that clear.
--
--     local Fixture = require("tests.support.fixture")
--
--     local c = Fixture.new(8, 8)
--     local hero = Fixture.unit("character_knight", 2, 2, { isolate = "bare", items = { "weapon_iron_sword" } })
--     local foe  = Fixture.unit("character_bandit", 2, 3, { stats = { defense = 0, health = 100 } })
--     local combat = Fixture.combat(c, { hero }, { foe })

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

local Fixture = {}

-- The tile every fixture board is paved with: open, cheap to cross, and transparent. `sightCost = 0`
-- is spelled out because the line-of-sight specs read it and a nil there behaves differently.
local function groundTile()
    return { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
end

--- A rectangular board of open ground.
--
-- `opts` is optional:
--   objective  -- the map objective, default { type = "killAll" }
--   tiles      -- a list of { x = , y = , <field> = ... } patches laid over the default tile, for
--                 the walls, cover, and field bonuses individual specs need
--   <anything else> -- copied onto the map table itself (`traps`, `seed`, ... )
function Fixture.new(cols, rows, opts)
    opts = opts or {}

    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = groundTile()
        end
    end

    for _, patch in ipairs(opts.tiles or {}) do
        local tile = tiles[patch.y] and tiles[patch.y][patch.x]
        assert(tile, "tile patch is off the board: (" .. tostring(patch.x) .. "," .. tostring(patch.y) .. ")")
        for field, value in pairs(patch) do
            if field ~= "x" and field ~= "y" then tile[field] = value end
        end
    end

    local map = {
        cols = cols,
        rows = rows,
        tiles = tiles,
        objective = opts.objective or { type = "killAll" },
    }
    for field, value in pairs(opts) do
        if field ~= "tiles" and field ~= "objective" then map[field] = value end
    end
    return map
end

-- How much of a character's blueprint kit to clear away before a case starts. Which baseline a test
-- stands on decides what its numbers mean, so it is named rather than implied:
--
--   "none" (default) -- the character exactly as authored, kit and innate intact. For tests that are
--                       ABOUT a blueprint (does Aurea carry her Purse?).
--   "mechanics"      -- traits and bound signature relics stripped. A blueprint's innate would
--                       otherwise perturb unit counts, initiative, and damage in a test that is about
--                       the engine, not the character.
--   "bare"           -- the whole 3x3 grid emptied, traits with it. The only clean baseline when the
--                       item under test is the variable, since every item can carry stats and traits
--                       to its holder.
local ISOLATION = {
    none = function() end,
    mechanics = function(char)
        char.traits = {}
        for i = 1, Character.MAX_INVENTORY do
            if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
        end
    end,
    bare = function(char)
        char.traits = {}
        char.inventory = {}
    end,
}

--- A { char, x, y } spawn entry, ready to hand to Fixture.combat.
--
-- `charOrId` is a blueprint id or an already-built character. `opts` is optional:
--   isolate -- "none" | "mechanics" | "bare" (see ISOLATION above), default "none"
--   stats   -- overrides applied after isolation; a resource stat sets max AND current together, so
--              { health = 100 } means "at full on 100", which is what a fixture almost always wants
--   items   -- item ids added to the grid in order (Character.addItem, so it fills real slots)
function Fixture.unit(charOrId, x, y, opts)
    opts = opts or {}
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId

    local isolate = ISOLATION[opts.isolate or "none"]
    assert(isolate, "unknown isolate level: " .. tostring(opts.isolate))
    isolate(char)

    for stat, value in pairs(opts.stats or {}) do
        if type(char.stats[stat]) == "table" then
            char.stats[stat].max, char.stats[stat].current = value, value
        else
            char.stats[stat] = value
        end
    end

    for _, id in ipairs(opts.items or {}) do
        Character.addItem(char, Item.instantiate(id))
    end

    return { char = char, x = x, y = y }
end

--- Combat.new, spelled the way the fixtures read. Accepts a bare spawn entry for the common
--- one-a-side case, so a test need not wrap a lone unit in a table.
function Fixture.combat(map, party, enemies)
    local function list(v) return (v and v.char) and { v } or (v or {}) end
    return Combat.new(map, list(party), list(enemies))
end

--- Open `u`'s turn, the precondition for Combat.useItem. Fresh: nothing moved, nothing spent.
function Fixture.openTurn(combat, u)
    combat.turn = { unit = u, moved = false, moveCost = 0 }
end

--- A unit's current health, the value most cases assert movement in.
function Fixture.hp(u) return u.char.stats.health.current end

--- The instance of `id` in `char`'s grid, or nil. Item ids repeat across a grid rarely enough that
--- the first match is the one meant.
function Fixture.itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local item = char.inventory[i]
        if item and item.id == id then return item end
    end
    return nil
end

--- Put `id` in `char`'s first grid cell and hand back the instance, for a case that wants a
--- known slot rather than wherever addItem lands.
function Fixture.give(char, id)
    local item = Item.instantiate(id)
    char.inventory[1] = item
    return item
end

--- Use `item` (an instance, or an id already in the attacker's grid) from `attacker` at `target`'s
--- tile, opening the turn first. Returns Combat.useItem's ok plus its result table -- the single
--- most common shape in an item test, which is otherwise four lines of ceremony.
function Fixture.strike(combat, attacker, target, item)
    if type(item) == "string" then
        item = Fixture.itemNamed(attacker.char, item) or Item.instantiate(item)
    end
    Fixture.openTurn(combat, attacker)
    return Combat.useItem(combat, attacker, item, target.x, target.y)
end

return Fixture
