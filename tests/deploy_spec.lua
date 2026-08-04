-- The deployment phase's model half: the DEPLOY ZONE the board hands the player, and the two-beat
-- battle open (build the ground, then ring the bell once the company is standing on it).
--
-- The interactive half -- dragging portraits out of the gutter strip onto lit tiles -- is
-- love.graphics-bound and lives in states/battle.lua; what is testable headless is everything it stands
-- on, and that is what this covers:
--   * every board offers a zone, it is standable, and it is WIDER than the party (a placement you have
--     no choice in is not a decision);
--   * an authored `deployZone` on a curated map wins outright;
--   * the zone never offers a tile the board itself already seated somebody on;
--   * Combat.new's `deferOpen` builds the world but fires no opener until Combat.openBattle, and doing
--     it the ordinary way is unchanged;
--   * a unit placed by Combat.deployUnit is a battle-start body (unclamped initiative), and can be
--     picked back up before the bell;
--   * a fight that skips the phase (deploy = false) still seats its party exactly as it always did.
-- Pure model logic, so it runs headless.

local Arena = require("models.arena")
local Combat = require("models.combat")
local Character = require("models.character")
local Fixture = require("tests.support.fixture")

local function build(spec)
    local s = { biome = "forest", seed = 11, party = { "character_knight", "character_mage" },
                composition = function() return { "character_bandit" } end }
    for k, v in pairs(spec or {}) do s[k] = v end
    return Arena.build({}, s)
end

local function key(t) return t.x .. "," .. t.y end

return {
    {
        name = "every board offers a deploy zone of standable ground",
        fn = function()
            local arena = build()
            assert(arena.deployZone, "the built arena carries a zone")
            assert(#arena.deployZone > 0, "the zone is not empty")
            for _, t in ipairs(arena.deployZone) do
                assert(arena.tiles[t.y] and arena.tiles[t.y][t.x], "zone tile is on the board")
                assert(arena.tiles[t.y][t.x].walkable, "zone tile is standable")
            end
        end,
    },
    {
        name = "the zone is wider than the party -- there is something to choose",
        fn = function()
            local arena = build({ party = { "character_knight", "character_mage" } })
            assert(#arena.deployZone > #arena.party,
                string.format("zone (%d) offers more tiles than the party has bodies (%d)",
                    #arena.deployZone, #arena.party))
        end,
    },
    {
        name = "the zone covers the rows the party's own spawns sit on",
        fn = function()
            local arena = build()
            local rows = {}
            for _, t in ipairs(arena.deployZone) do rows[t.y] = true end
            for _, u in ipairs(arena.party) do
                assert(rows[u.y], "the zone includes the row a party spawn was seated on (y=" .. u.y .. ")")
            end
        end,
    },
    {
        name = "no zone tile is one the board already seated somebody on",
        fn = function()
            -- An escort fight: the ally is authored onto the party's own near rows (bindAllies), and the
            -- phase must never offer the player the tile it is standing on.
            local arena = build({
                allies = function() return { "character_knight" } end,
                objective = { type = "protect", protect = "character_knight" },
            })
            local taken = {}
            for _, u in ipairs(arena.allies or {}) do taken[key(u)] = true end
            for _, u in ipairs(arena.enemies or {}) do taken[key(u)] = true end
            for _, t in ipairs(arena.deployZone) do
                assert(not taken[key(t)], "the zone excludes a tile somebody is already on: " .. key(t))
            end
        end,
    },
    {
        name = "an authored deployZone on a curated map wins outright",
        fn = function()
            -- Stand a curated layout in the registry for the length of this case: the authored zone is
            -- two named tiles, and the built arena must offer exactly those (both walkable, neither taken).
            local id = "test_authored_zone"
            local tiles = {}
            for y = 1, 8 do
                tiles[y] = {}
                for x = 1, 8 do tiles[y][x] = "ground" end
            end
            Arena.defs[id] = {
                biome = "forest", fixed = true, tiles = tiles,
                partySpawns = { { x = 4, y = 8 }, { x = 5, y = 8 } },
                enemySpawns = { { x = 4, y = 1 } },
                deployZone = { { x = 2, y = 7 }, { x = 3, y = 7 } },
            }
            local ok, arena = pcall(build, { layout = id })
            Arena.defs[id] = nil
            assert(ok, "the authored board builds")
            assert(#arena.deployZone == 2, "exactly the authored tiles are offered")
            local seen = {}
            for _, t in ipairs(arena.deployZone) do seen[key(t)] = true end
            assert(seen["2,7"] and seen["3,7"], "the offered tiles are the authored ones")
        end,
    },
    {
        name = "deferOpen builds the world but does not ring the bell",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6), {},
                { Fixture.unit("character_bandit", 3, 1) }, { deferOpen = true })
            assert(c.opened == false, "the battle is not open yet")
            assert(c.props and c.hazards and c.traps and c.walls, "the world was still laid down")
            -- "The battle begins." is the opener's own first line; nothing has been said yet.
            assert(#(c.log or {}) == 0, "nothing has been logged before the bell")
            Combat.openBattle(c)
            assert(c.opened, "openBattle opens it")
            assert(#c.log > 0, "the opening line is logged once the bell rings")
        end,
    },
    {
        name = "openBattle is idempotent -- an opener never fires twice",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6), {},
                { Fixture.unit("character_bandit", 3, 1) }, { deferOpen = true })
            Combat.openBattle(c)
            local n = #c.log
            Combat.openBattle(c)
            assert(#c.log == n, "a second open says and does nothing")
        end,
    },
    {
        name = "the ordinary (undeferred) path is unchanged: built and open in one call",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6),
                { Fixture.unit("character_knight", 2, 5) },
                { Fixture.unit("character_bandit", 3, 1) })
            assert(c.opened, "a battle built the ordinary way is already open")
            assert(#c.log > 0, "and has said so")
        end,
    },
    {
        name = "a deployed unit is a battle-start body, and can be picked back up before the bell",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6), {},
                { Fixture.unit("character_bandit", 3, 1) }, { deferOpen = true })
            local char = Character.instantiate("character_knight")
            local unit = Combat.deployUnit(c, char, 2, 5)
            assert(unit and unit.side == "party" and unit.x == 2 and unit.y == 5, "stood where it was put")
            assert(unit.initiative == Combat.initiative(char),
                "a battle-start body takes its natural initiative, unclamped")
            assert(#c.units == 2, "it joined the board")
            assert(Combat.undeployUnit(c, unit), "and can be taken back off")
            assert(#c.units == 1, "leaving no trace on the board")
            for i, u in ipairs(c.units) do
                assert(u.index == i, "the remaining units' indices still match their positions")
            end
        end,
    },
    {
        name = "undeploy is refused once the battle has opened -- combat.units only grows from there",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6),
                { Fixture.unit("character_knight", 2, 5) },
                { Fixture.unit("character_bandit", 3, 1) })
            assert(Combat.undeployUnit(c, c.units[1]) == false, "an opened battle refuses the undo")
            assert(#c.units == 2, "and keeps the body")
        end,
    },
    {
        name = "with no formation and no phase, a board still auto-spreads the party as it always did",
        fn = function()
            local layout = Arena.generateLayout({ seed = 3, party = 3, enemies = 2 })
            assert(#layout.partySpawns == 3, "everyone is seated")
            for _, sp in ipairs(layout.partySpawns) do
                assert(sp.y == layout.rows or sp.y == layout.rows - 1,
                    "auto-placed members stand on the two near rows")
            end
        end,
    },
    {
        name = "draft's pre-resolved marching slots still seat a curated board",
        fn = function()
            -- The one caller left that brings a formation. Both members on the front row: they seat one
            -- row ahead of the home edge, on walkable ground, never on the colosseum's shoulder pillars.
            local slots = { { col = 2, row = 1 }, { col = 3, row = 1 } }
            local built = Arena.build({}, {
                biome = "castle", layout = "colosseum_sand", seed = 1,
                party = { "a", "b" }, composition = function() return { "x" } end,
                formation = slots, formationCols = 4, formationRows = 2,
            })
            for _, u in ipairs(built.party) do
                assert(u.y < built.rows, "an arranged front-row party stands ahead of the home edge")
                assert(built.tiles[u.y][u.x].walkable, "no member is seated on a wall")
            end
        end,
    },
}
