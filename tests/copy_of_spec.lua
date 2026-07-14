-- Tests for Summon.copyOf (models/summon.lua): taking the shape of SOMEONE ELSE. Where Summon.copy
-- duplicates the caster, this puts a duplicate of an arbitrary unit on the copier's side -- the
-- Philosopher's Stone, and the general of Envy who will one day point it back at you.
--
-- The guarantee that matters most is inherited rather than written: a copy is `summoned`, and both
-- Combat.evaluate's assassinate branch and Combat.isProtectedAlive already filter on that flag. So
-- copying an assassination target does not spare it, and copying an escorted charge does not stand in
-- for it. Those two are asserted here for an arbitrary target, as summon_spec asserts them for a self-copy.
--
-- Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Summon = require("models.summon")
local Trap = require("models.trap")

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    -- Isolate from the innate, which now rides on a bound signature relic in the grid (see
    -- tests/innate_spec.lua): strip that relic. A lone archer would otherwise field a wolf and skew the
    -- unit counts these copy tests assume.
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

return {
    {
        name = "copyOf lifts a foe's current stats and kit onto the copier's own side",
        fn = function()
            local bandit = Character.instantiate("bandit")
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit(bandit, 5, 5) })
            local mage, foe = c.units[1], c.units[2]

            -- Wound it first: a copy is taken from what stands there now, not from the blueprint.
            foe.char.stats.health.current = foe.char.stats.health.max - 7

            local shape = Summon.copyOf(c, mage, foe, 2, 1)

            assert(shape.alive, "the shape should arrive standing")
            assert(shape.side == "party", "it fights for the copier, not for the thing it copied")
            assert(shape.char.id == "bandit", "it is a bandit")
            assert(shape.char.stats.health.current == foe.char.stats.health.max - 7,
                "it should carry the wound its original was carrying")

            -- Separate bodies: spending the copy's health must not touch the original's.
            shape.char.stats.health.current = 1
            assert(foe.char.stats.health.current == foe.char.stats.health.max - 7,
                "the original is untouched by what happens to its shape")
        end,
    },
    {
        name = "the copy's grid is its own, and never carries a noCopy item",
        fn = function()
            local rogue = Character.instantiate("bandit")
            Character.addItem(rogue, Item.instantiate("decoy")) -- noCopy
            Character.addItem(rogue, Item.instantiate("healing_potion"))

            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit(rogue, 5, 5) })
            local mage, foe = c.units[1], c.units[2]

            local shape = Summon.copyOf(c, mage, foe, 2, 1)

            assert(not itemNamed(shape.char, "decoy"), "a noCopy item must not be duplicated")
            assert(itemNamed(shape.char, "healing_potion"), "ordinary kit comes along")

            local original = itemNamed(foe.char, "healing_potion")
            local copied = itemNamed(shape.char, "healing_potion")
            assert(original ~= copied, "the copy holds its own instance, not a shared reference")
        end,
    },
    {
        name = "an enemy that copies your knight does not satisfy an assassinate on the knight",
        fn = function()
            local c = Combat.new(arena(8, 8, { type = "assassinate", target = "bandit_chief" }),
                { unit("knight", 1, 1) }, { unit("bandit_chief", 5, 5) })
            local knight, chief = c.units[1], c.units[2]

            -- The mark copies its hunter: an enemy-side unit now carries char.id "knight".
            local shape = Summon.copyOf(c, chief, knight, 5, 4)
            assert(shape.side == "enemy" and shape.char.id == "knight", "the enemy wears your face")
            assert(shape.summoned, "and the shape is marked as a summon")

            -- And the reverse: copying the mark does not kill the mark.
            local mimic = Summon.copyOf(c, knight, chief, 1, 2)
            assert(mimic.char.id == "bandit_chief", "the copy shares the mark's id")
            assert(Combat.evaluate(c) == nil, "the real chief still stands, so nothing is resolved")

            Combat.dealFlatDamage(c, chief, 9999, nil, "test")
            assert(Combat.evaluate(c) == "win", "killing the real one resolves it")
        end,
    },
    {
        name = "a copy of an escorted charge does not stand in for the charge itself",
        fn = function()
            local c = Combat.new(arena(8, 8, { type = "killAll", protect = "caravan_master" }),
                { unit("knight", 1, 1), unit("caravan_master", 2, 1) }, { unit("bandit", 5, 5) })
            local knight, charge = c.units[1], c.units[2]

            Summon.copyOf(c, knight, charge, 3, 1)
            assert(Combat.isProtectedAlive(c, "caravan_master"), "the real charge is alive")

            Combat.dealFlatDamage(c, charge, 9999, nil, "test")
            assert(not Combat.isProtectedAlive(c, "caravan_master"),
                "a duplicate must not keep a dead escort's objective alive")
            assert(Combat.evaluate(c) == "loss", "so the escort is failed")
        end,
    },
    {
        name = "the shape is bound to whoever wore it: killing the copier dismisses the copy",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit_chief", 5, 5) })
            local knight, chief = c.units[1], c.units[2]

            local shape = Summon.copyOf(c, chief, knight, 5, 4)
            assert(shape.summoner == chief, "by default the copier sustains its shape")

            Combat.dealFlatDamage(c, chief, 9999, nil, "test")
            assert(not shape.alive, "the shape goes with the thing that was wearing it")
        end,
    },
    {
        name = "summoner = false leaves a shape that outlives its maker",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit_chief", 5, 5) })
            local knight, chief = c.units[1], c.units[2]

            local shape = Summon.copyOf(c, chief, knight, 5, 4, { summoner = false })
            assert(shape.summoner == nil, "nothing sustains it")

            Combat.dealFlatDamage(c, chief, 9999, nil, "test")
            assert(shape.alive, "so it stands after its maker falls")
            assert(shape.summoned, "and it is still not a real combatant")
        end,
    },
    {
        name = "an enemy's shape is AI-run; the player's is theirs to command",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit_chief", 5, 5) })
            local knight, chief = c.units[1], c.units[2]

            local theirs = Summon.copyOf(c, chief, knight, 5, 4)
            assert(not Combat.isPlayerControlled(theirs), "an enemy copy runs itself")

            local ours = Summon.copyOf(c, knight, chief, 1, 2)
            assert(Combat.isPlayerControlled(ours), "the player's copy takes the cursor")
        end,
    },
    {
        name = "a fragile shape set down on a lethal trap dies on arrival, binding nothing",
        fn = function()
            Trap.defs.test_slayer = { name = "Slayer", health = 1,
                onTrigger = function(ctx) ctx.damage(ctx.victim, 9999, {}) end }
            local ok, err = pcall(function()
                local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("bandit", 6, 6) })
                local mage, foe = c.units[1], c.units[2]
                Trap.place(c, 2, 1, "test_slayer", "enemy")

                local shape = Summon.copyOf(c, mage, foe, 2, 1, { fragile = true })
                assert(not shape.alive, "the trap under it is lethal, and it is fragile besides")
            end)
            Trap.defs.test_slayer = nil -- don't leak the fixture
            if not ok then error(err, 0) end
        end,
    },
    {
        name = "the Philosopher's Stone transmutes a foe into an ally beside its caster",
        fn = function()
            local mage = Character.instantiate("mage")
            mage.inventory = {} -- clear the full hero grid (incl. the innate relic) to make room for the Stone
            Character.addItem(mage, Item.instantiate("philosophers_stone"))

            local c = Combat.new(arena(8, 8), { unit(mage, 3, 3) }, { unit("bandit", 3, 5) })
            local caster, foe = c.units[1], c.units[2]
            openTurn(c, caster)

            local stone = itemNamed(caster.char, "philosophers_stone")
            local before = #c.units
            local ok = Combat.useItem(c, caster, stone, foe.x, foe.y)

            assert(ok, "the cast should land")
            assert(#c.units == before + 1, "a shape should have been set down")

            local shape = c.units[#c.units]
            assert(shape.char.id == "bandit", "it wears the foe's shape")
            assert(shape.side == "party", "and fights for the caster")
            assert(shape.fragile, "one hit destroys it")
            assert(math.abs(shape.x - caster.x) <= 1 and math.abs(shape.y - caster.y) <= 1,
                "it is set down beside its caster, not beside the foe it was lifted from")
            assert(stone.activeSummon == shape, "one shape at a time, per item")
        end,
    },
    {
        name = "the Stone's tooltip names what it would summon without touching the board",
        fn = function()
            local mage = Character.instantiate("mage")
            mage.inventory = {} -- clear the full hero grid (incl. the innate relic) to make room for the Stone
            Character.addItem(mage, Item.instantiate("philosophers_stone"))
            local c = Combat.new(arena(8, 8), { unit(mage, 3, 3) }, { unit("bandit", 3, 5) })
            local caster = c.units[1]

            local before = #c.units
            local out = Combat.abilityOutput(caster, itemNamed(caster.char, "philosophers_stone"))
            assert(out.summon, "the tooltip should say it summons something")
            assert(#c.units == before, "and the dry run must not put anything on the field")
        end,
    },
}
