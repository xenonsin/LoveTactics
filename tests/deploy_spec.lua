-- The deployment phase's model half: the DEPLOY ZONE the board hands the player, and the two-beat
-- battle open (build the ground, then ring the bell once the company is standing on it).
--
-- The interactive half -- dragging portraits out of the gutter strip onto lit tiles -- is
-- love.graphics-bound and lives in states/battle.lua; what is testable headless is everything it stands
-- on, and that is what this covers:
--   * every board offers a zone, it is standable, and it is WIDER than the field (a placement you have
--     no choice in is not a decision) -- by default the fixed bottom-centre block, on every board;
--   * an authored `deployZone` on a curated map wins outright;
--   * the zone never offers a tile the board itself already seated somebody on -- a wide body by its
--     whole footprint and not merely the corner it is anchored on, and Combat.deployUnit refuses such a
--     tile anyway, so a phase that somehow offers one still cannot stack two bodies on it;
--   * Combat.new's `deferOpen` builds the world but fires no opener until Combat.openBattle, and doing
--     it the ordinary way is unchanged;
--   * a unit placed by Combat.deployUnit is a battle-start body (unclamped initiative), and can be
--     picked back up before the bell;
--   * a body already standing re-reads what its GEAR decides when the phase's Loadout screen changes it
--     under them (Combat.restampDeployed), and refuses to once the bell has rung;
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
        name = "the zone is wider than the field -- there is something to choose",
        fn = function()
            local arena = build({ party = { "character_knight", "character_mage" } })
            assert(#arena.deployZone > Arena.DEPLOY_MIN,
                string.format("zone (%d) offers more tiles than the field cap (%d)",
                    #arena.deployZone, Arena.DEPLOY_MIN))
        end,
    },
    {
        name = "an unauthored board deploys on the bottom-centre block",
        fn = function()
            -- The default is the same eight tiles on every board: four columns centred on the width,
            -- two rows deep against the party's own edge. Not the rows the spawns happened to land on.
            local arena = build()
            local w, d = Arena.DEPLOY_COLS, Arena.DEPLOY_DEPTH
            local x0 = math.floor((arena.cols - w) / 2) + 1
            local want = {}
            for y = arena.rows - d + 1, arena.rows do
                for x = x0, x0 + w - 1 do want[x .. "," .. y] = true end
            end
            assert(#arena.deployZone == w * d,
                string.format("the block is %dx%d tiles, got %d", w, d, #arena.deployZone))
            for _, t in ipairs(arena.deployZone) do
                assert(want[key(t)], "zone tile " .. key(t) .. " is outside the bottom-centre block")
            end
        end,
    },
    {
        name = "the whole marching company does not widen the zone",
        fn = function()
            -- `spec.party` is the entire roster (states/game.lua hands over player.roster), and only
            -- four of them stand at once: a company larger than the block must not read as "too
            -- cramped" and drop the zone back onto the spawn spread.
            local big = {}
            for i = 1, 9 do big[i] = (i % 2 == 0) and "character_mage" or "character_knight" end
            local arena = build({ party = big })
            assert(#arena.deployZone == Arena.DEPLOY_COLS * Arena.DEPLOY_DEPTH,
                "a nine-strong company still gets the eight-tile block, got " .. #arena.deployZone)
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
        name = "a wide body takes the zone off every cell it covers, not just its anchor",
        fn = function()
            -- An ogre is a 2x2 block (data/characters/character_ogre.lua). One authored into the party's
            -- own near rows has to take all four of its cells out of the zone: marking only the corner
            -- it is anchored on left the other three lit, which is how a knight ended up standing inside
            -- one at the opening bell.
            local id = "test_wide_body_zone"
            local tiles = {}
            for y = 1, 8 do
                tiles[y] = {}
                for x = 1, 8 do tiles[y][x] = "ground" end
            end
            Arena.defs[id] = {
                biome = "forest", fixed = true, tiles = tiles,
                partySpawns = { { x = 6, y = 8 }, { x = 7, y = 8 } },
                enemySpawns = { { x = 3, y = 7 } },
            }
            local ok, arena = pcall(build,
                { layout = id, composition = function() return { "character_ogre" } end })
            Arena.defs[id] = nil
            assert(ok, "the board builds: " .. tostring(arena))

            local foe = arena.enemies[1]
            assert(foe and foe.x == 3 and foe.y == 7, "the ogre stands where the board seated it")
            local offered = {}
            for _, t in ipairs(arena.deployZone) do offered[key(t)] = true end
            for _, c in ipairs({ { x = 3, y = 7 }, { x = 4, y = 7 }, { x = 3, y = 8 }, { x = 4, y = 8 } }) do
                assert(not offered[key(c)], "the zone offers a cell the ogre's body covers: " .. key(c))
            end
            assert(#arena.deployZone > 0, "and there is still ground left to stand the company on")
        end,
    },
    {
        name = "nobody is stood inside a body that is already on the board",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6), {},
                { Fixture.unit("character_ogre", 3, 3) }, { deferOpen = true })
            assert(c.units[1].w == 2 and c.units[1].h == 2, "the ogre covers a 2x2 block")
            for _, cell in ipairs({ { 3, 3 }, { 4, 3 }, { 3, 4 }, { 4, 4 } }) do
                assert(Combat.deployUnit(c, Character.instantiate("character_knight"), cell[1], cell[2]) == nil,
                    string.format("(%d,%d) is under the ogre and refuses a body", cell[1], cell[2]))
            end
            assert(#c.units == 1, "and no refused body was left on the board")

            assert(Combat.deployUnit(c, Character.instantiate("character_knight"), 2, 6),
                "clear ground still takes one")
            assert(Combat.deployUnit(c, Character.instantiate("character_mage"), 2, 6) == nil,
                "the tile it is standing on refuses the next")
            assert(Combat.deployUnit(c, Character.instantiate("character_mage"), 7, 6) == nil,
                "as does ground off the board")
            assert(#c.units == 2, "one ogre, one knight")
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
        -- The deployment phase's Loadout screen (ui/deploy_phase.lua) can re-kit a body that is already
        -- standing. Initiative is the average speed of the ability items it carries, snapshotted when it
        -- was stood up, so a swap made afterwards has to be re-read or the fight opens on the tempo of a
        -- weapon nobody is holding.
        name = "a standing body re-reads its tempo when its gear changes under it",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6), {},
                { Fixture.unit("character_bandit", 3, 1) }, { deferOpen = true })
            local char = Character.instantiate("character_knight")
            local unit = Combat.deployUnit(c, char, 2, 5)
            local before = unit.initiative

            -- Take the whole kit off it: with no ability item left, its tempo falls back to the hidden
            -- unarmed weapon's. A blunter edit than the screen would make, and it needs no particular
            -- item to stay true as the shelf is retuned.
            for i = 1, 9 do char.inventory[i] = nil end
            assert(unit.initiative == before, "an untouched unit is not re-read by the swap itself")

            assert(Combat.restampDeployed(c, unit), "an unopened board re-stamps")
            assert(unit.initiative ~= before, "the tempo moved with the weapon")
            assert(unit.initiative == Combat.initiative(char), "and is exactly what the new kit says")
            assert(unit.x == 2 and unit.y == 5 and #c.units == 2,
                "nobody moved and nobody was rebuilt -- only the snapshot was re-read")
        end,
    },
    {
        name = "re-stamping is refused once the battle has opened",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6),
                { Fixture.unit("character_knight", 2, 5) },
                { Fixture.unit("character_bandit", 3, 1) })
            assert(Combat.restampDeployed(c, c.units[1]) == false,
                "an opened battle is past the point gear may be re-read this way")
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
    {
        name = "the phase shows the board it is deploying onto, not just the lit zone",
        fn = function()
            -- The interactive half is love.graphics-bound (see this file's header), so the wiring is
            -- read off the source rather than driven. What it pins: the phase hands the board EVERY
            -- static object standing on it. It shipped lighting the deploy zone and nothing else, which
            -- left the barrel beside the chokepoint, the biome's fire and an authored trap invisible for
            -- the one decision they exist to inform -- while the phase's own hover box described them
            -- perfectly well to anyone who thought to hover a tile they could not see.
            -- Line endings normalised first: the tree is CRLF on Windows, and a pattern anchored on "\n"
            -- matches nothing there -- a source scan that cannot fail is not a test.
            local src = assert(love.filesystem.read("states/battle.lua"), "cannot read states/battle.lua")
            src = src:gsub("\r", "")
            local body = src:match("local function deployOverlays%(%)(.-)\nend\n")
            assert(body, "deployOverlays is gone from states/battle.lua")
            for _, want in ipairs({ "deployZone", "overlays%.hazards", "overlays%.props",
                                    "overlays%.walls", "overlays%.traps", "overlays%.objective" }) do
                assert(body:find(want), "the phase no longer shows " .. want:gsub("%%", ""))
            end
            assert(src:find("setOverlays%(deployOverlays%(%)%)"),
                "openDeployPhase no longer hands the phase the board's own objects")
        end,
    },
}
