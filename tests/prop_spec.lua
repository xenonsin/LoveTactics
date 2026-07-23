-- Tests for props (models/prop.lua): the board's own furniture -- barrels and crates scattered by the
-- map generator off the biome, owned by nobody, triggered by being HIT rather than stepped on, and
-- light enough to pick up and throw. Covers the four seams the layer spans: the generator's scatter,
-- the object's blocking/striking behaviour, the blast (and its chain), and Heave's widened grip --
-- props, traps and banners as well as bodies. Pure logic, runs headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Arena = require("models.arena")
local Prop = require("models.prop")
local Trap = require("models.trap")
local Hazard = require("models.hazard")
local Item = require("models.item")

-- A flat, all-walkable arena (mirrors tests/knockback_spec.lua). `blocked` lists {x, y} cells made
-- impassable, which is what a throw slams its cargo into.
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

local function hp(u) return u.char.stats.health.current end

-- Give `u` an item so it can act (Heave, a keg). Grid slot 1 is enough for every use here.
local function grant(u, itemId)
    local item = Item.instantiate(itemId)
    u.char.inventory[1] = item
    return item
end

return {
    -- -----------------------------------------------------------------------
    -- Scatter: which props a biome fields, and reproducibly
    -- -----------------------------------------------------------------------
    {
        name = "a generated board scatters props from its biome's own pool",
        fn = function()
            local layout = Arena.generateLayout({ seed = 4242, biome = "castle", party = 2, enemies = 2 })
            assert(layout.props, "a generated layout always carries a props list, even an empty one")
            for _, p in ipairs(layout.props) do
                assert(Prop.defs[p.id], "every scattered id names a real prop blueprint: " .. tostring(p.id))
                assert(layout.tiles[p.y][p.x] == "ground", "a prop only ever stands on plain ground")
            end
        end,
    },
    {
        name = "the same seed scatters the same props, and a different one need not",
        fn = function()
            local a = Arena.generateLayout({ seed = 99, biome = "castle", party = 2, enemies = 2 })
            local b = Arena.generateLayout({ seed = 99, biome = "castle", party = 2, enemies = 2 })
            assert(#a.props == #b.props, "a board replays from its seed, objects and all")
            for i, p in ipairs(a.props) do
                assert(b.props[i].id == p.id and b.props[i].x == p.x and b.props[i].y == p.y,
                    "every prop lands in the same place on the replay")
            end
        end,
    },
    {
        name = "a prop only scatters into the biomes it names",
        fn = function()
            -- The crate is stocked for forest/castle and nowhere else, so the underworld's pool must
            -- not contain it however many times it is rolled.
            local pool = Prop.poolFor("underworld")
            for _, entry in ipairs(pool) do
                assert(entry.id ~= "prop_crate", "nothing down there ships supplies")
            end
            local ids = {}
            for _, entry in ipairs(Prop.poolFor("forest")) do ids[entry.id] = true end
            assert(ids["prop_crate"], "a forest trail does field crates")
        end,
    },
    {
        name = "a biome no prop names fields none at all",
        fn = function()
            local pool, total = Prop.poolFor("a biome nobody has written")
            assert(#pool == 0 and total == 0, "an unlisted biome opts out by omission")
            local rng = love.math.newRandomGenerator(7)
            assert(#Prop.roll(rng, "a biome nobody has written", 5) == 0, "and rolling it draws nothing")
        end,
    },

    -- -----------------------------------------------------------------------
    -- Standing on the board
    -- -----------------------------------------------------------------------
    {
        name = "a prop blocks its tile, and a second one cannot share it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 8, 8) })
            assert(Prop.place(c, 4, 4, "prop_crate"), "the crate stands on open ground")
            assert(Combat.objectBlocksAt(c, 4, 4), "and bars the way like any standing object")
            assert(not Prop.place(c, 4, 4, "prop_crate"), "one prop per tile")
            assert(not Prop.place(c, 1, 1, "prop_crate"), "and never on a tile a body already holds")
        end,
    },
    {
        name = "a crate is soft cover: one lowers a line of sight, two together break it",
        fn = function()
            local c = Combat.new(arena(10, 3), { unit("character_knight", 1, 2) }, { unit("character_bandit", 8, 2) })
            assert(Combat.hasLineOfSight(c, 1, 2, 8, 2), "open ground sees clear across")
            Prop.place(c, 4, 2, "prop_crate")
            assert(Combat.hasLineOfSight(c, 1, 2, 8, 2), "one crate is cover, not a wall")
            Prop.place(c, 5, 2, "prop_crate")
            assert(not Combat.hasLineOfSight(c, 1, 2, 8, 2), "two stacked shut the lane")
        end,
    },
    {
        name = "a barrel screens nothing -- you can always shoot over it, which is how you pop it",
        fn = function()
            local c = Combat.new(arena(10, 3), { unit("character_knight", 1, 2) }, { unit("character_bandit", 8, 2) })
            Prop.place(c, 4, 2, "prop_explosive_barrel")
            Prop.place(c, 5, 2, "prop_explosive_barrel")
            assert(Combat.hasLineOfSight(c, 1, 2, 8, 2), "a keg is waist-high; the shot goes over it")
        end,
    },

    -- -----------------------------------------------------------------------
    -- The blast
    -- -----------------------------------------------------------------------
    {
        name = "any blow at all sets off a barrel, and the blast takes both sides",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 4, 5) }, { unit("character_bandit", 4, 3) })
            local knight, bandit = c.units[1], c.units[2]
            local barrel = Prop.place(c, 4, 4, "prop_explosive_barrel")
            local kBefore, bBefore = hp(knight), hp(bandit)

            Prop.damage(c, barrel, 1)
            assert(not barrel.alive, "one hit -- any hit -- is a killing blow on a keg")
            assert(hp(knight) < kBefore, "the party standing beside it wears the blast too")
            assert(hp(bandit) < bBefore, "and so does the enemy: a barrel has no side")
        end,
    },
    {
        name = "the blast reaches one tile and no further",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 4, 6) }, { unit("character_bandit", 4, 3) })
            local far, near = c.units[1], c.units[2]
            local before = hp(far)
            Prop.damage(c, Prop.place(c, 4, 4, "prop_explosive_barrel"), 1)
            assert(hp(near) < 100000 and hp(far) == before, "two tiles out is out of the ring")
        end,
    },
    {
        name = "kegs chain: setting off one sets off its neighbour, and the chain terminates",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 1, 1) }, { unit("character_bandit", 8, 8) })
            local a = Prop.place(c, 4, 4, "prop_explosive_barrel")
            local b = Prop.place(c, 5, 4, "prop_explosive_barrel")
            local d = Prop.place(c, 6, 4, "prop_explosive_barrel")

            Prop.damage(c, a, 1)
            assert(not a.alive and not b.alive and not d.alive,
                "the whole line goes up, each keg setting off the next")
        end,
    },
    {
        name = "a barrel's blast splinters the inert props beside it",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 1, 1) }, { unit("character_bandit", 8, 8) })
            local crate = Prop.place(c, 5, 4, "prop_crate")
            Prop.damage(c, Prop.place(c, 4, 4, "prop_explosive_barrel"), 1)
            assert(not crate.alive, "a crate standing next to a bomb does not survive the bomb")
        end,
    },
    {
        name = "a body shoved into a barrel sets it off, with nothing written to say so",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 3, 4) }, { unit("character_bandit", 4, 4) })
            local knight, bandit = c.units[1], c.units[2]
            local barrel = Prop.place(c, 5, 4, "prop_explosive_barrel")
            local before = hp(bandit)

            local moved, collided = Combat.knockback(c, knight, bandit, 3)
            assert(moved == 0 and collided, "the keg stopped the shove where it stood")
            assert(not barrel.alive, "and being slammed into is being hit")
            assert(hp(bandit) < before, "the shoved body wears the impact and then the blast")
        end,
    },

    -- -----------------------------------------------------------------------
    -- Heave: bodies, props, traps, banners
    -- -----------------------------------------------------------------------
    {
        name = "Heave throws the prop on the tile it grabs",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_knight", 3, 5) }, { unit("character_bandit", 10, 10) })
            local knight = c.units[1]
            local heave = grant(knight, "ability_heave")
            local crate = Prop.place(c, 4, 5, "prop_crate")

            Combat.startTurn(c, knight)
            assert(Combat.useItem(c, knight, heave, 4, 5), "an adjacent tile holding furniture is a legal grab")
            assert(crate.alive and crate.x == 7 and crate.y == 5,
                "it travels the full three tiles down the lane and lands intact on open ground")
        end,
    },
    {
        name = "a keg heaved into a body bursts on impact and hurts what it hit",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_knight", 3, 5) }, { unit("character_bandit", 6, 5) })
            local knight, bandit = c.units[1], c.units[2]
            local heave = grant(knight, "ability_heave")
            local barrel = Prop.place(c, 4, 5, "prop_explosive_barrel")
            local before = hp(bandit)

            Combat.startTurn(c, knight)
            Combat.useItem(c, knight, heave, 4, 5)
            assert(not barrel.alive, "the collision destroys a one-HP keg, which is the keg going off")
            assert(hp(bandit) < before, "the body it slammed into takes the impact and the blast")
        end,
    },
    {
        name = "Heave picks up a trap it can see and puts it somewhere better",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_knight", 3, 5) }, { unit("character_bandit", 10, 10) })
            local knight = c.units[1]
            local heave = grant(knight, "ability_heave")
            local trap = Trap.place(c, 4, 5, "spike_trap", "party") -- the party's own, so it is visible

            Combat.startTurn(c, knight)
            assert(Combat.useItem(c, knight, heave, 4, 5), "a tile holding a trap is a legal grab")
            assert(trap.alive and trap.x == 7 and trap.y == 5, "the trap is relocated down the lane")
        end,
    },
    {
        name = "Heave cannot grab a trap its side has not found",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_knight", 3, 5) }, { unit("character_bandit", 10, 10) })
            local knight = c.units[1]
            local trap = Trap.place(c, 4, 5, "spike_trap", "enemy") -- hidden: no detector in the party
            assert(not Combat.throwableAt(c, 4, 5, "party"), "you cannot heave what you have not detected")
            assert(Combat.throwableAt(c, 4, 5, "enemy"), "its owner sees it perfectly well")
            assert(trap.x == 4, "and nothing moved it")
        end,
    },
    {
        name = "Heave throws a planted banner, and the ground it holds open goes with it",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_knight", 3, 5) }, { unit("character_bandit", 10, 10) })
            local knight = c.units[1]
            local heave = grant(knight, "ability_heave")

            -- Plant a banner by hand (the ability that raises one is a different test's business) and
            -- give it the 3x3 rally square it owns.
            local banner = Combat.addUnit(c, Character.instantiate("character_banner"), "party", 4, 5,
                { control = "none", timeless = true, summoned = true })
            for dy = -1, 1 do
                for dx = -1, 1 do
                    Hazard.place(c, 4 + dx, 5 + dy, "hazard_rally", { owner = banner, side = "party" })
                end
            end
            assert(Hazard.at(c, 4, 5, "hazard_rally"), "the square stands under the standard")

            Combat.startTurn(c, knight)
            assert(Combat.useItem(c, knight, heave, 4, 5), "a banner is a body, so Heave grabs it")
            assert(banner.x == 7 and banner.y == 5, "the standard travels three tiles")
            assert(Hazard.at(c, 7, 5, "hazard_rally"), "and its rally square arrives with it")
            assert(not Hazard.at(c, 4, 5, "hazard_rally"),
                "leaving no blessing lit over the ground it used to stand on")
        end,
    },
    {
        name = "carried ground keeps its shape, and clips on what it is thrown against",
        fn = function()
            -- A banner heaved to the board's edge: the far column of its square would land off the map.
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 4, 5) }, { unit("character_bandit", 1, 1) })
            local banner = Combat.addUnit(c, Character.instantiate("character_banner"), "party", 5, 5,
                { control = "none", timeless = true, summoned = true })
            for dy = -1, 1 do
                for dx = -1, 1 do
                    Hazard.place(c, 5 + dx, 5 + dy, "hazard_rally", { owner = banner, side = "party" })
                end
            end
            assert(#Hazard.allAt(c, 5, 5) > 0, "the square existed to begin with")

            Combat.knockback(c, c.units[1], banner, 3)
            assert(banner.x == 8, "shoved to the last tile that will take it -- the board's edge")
            assert(Hazard.at(c, 8, 5, "hazard_rally"), "the square's heart follows the standard")
            assert(Hazard.at(c, 7, 5, "hazard_rally"), "and the column behind it keeps its shape")
            assert(not Hazard.at(c, 9, 5, "hazard_rally"), "while the column that fell off the map is gone")
        end,
    },

    -- -----------------------------------------------------------------------
    -- Placing one: the alchemist's keg
    -- -----------------------------------------------------------------------
    {
        name = "Powder Keg stands the same barrel the map scatters, scaled by its upgrade level",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit("character_knight", 3, 5) }, { unit("character_bandit", 10, 10) })
            local caster = c.units[1]
            local keg = grant(caster, "ability_powder_keg")

            Combat.startTurn(c, caster)
            assert(Combat.useItem(c, caster, keg, 5, 5), "an empty tile in range takes a barrel")
            local placed = Prop.at(c, 5, 5)
            assert(placed and placed.id == "prop_explosive_barrel",
                "it is the board's own barrel, not a private copy of one")
            assert(placed.amount and placed.amount >= 16, "and it carries the level-scaled blast")
        end,
    },
    {
        name = "a placed keg is a threat to whoever sets it off, not to a side",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_knight", 4, 5) }, { unit("character_bandit", 4, 3) })
            local knight = c.units[1]
            local barrel = Prop.place(c, 4, 4, "prop_explosive_barrel", { amount = 30 })
            local before = hp(knight)
            Prop.damage(c, barrel, 1)
            assert(hp(knight) < before - 5, "the party that placed it is standing too close to it")
        end,
    },
    {
        name = "Prop.preview quotes the blast without a board to fire it on",
        fn = function()
            local out = Prop.preview("prop_explosive_barrel", 24)
            assert(out and out.damage == 24, "the tooltip reads the prop's own effect, not a copy of it")
            assert(Prop.preview("prop_crate").damage == 0, "an inert prop previews as inert")
            assert(Prop.preview("no such prop") == nil, "and an unknown id previews as nothing")
        end,
    },
}
