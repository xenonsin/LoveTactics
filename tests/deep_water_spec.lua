-- DEEP WATER, and the one sentence the whole feature stands on: nobody walks in. You get PUT there.
--
-- Three separate claims live in three separate files and none of them can see the others, which is why
-- this spec exists rather than a paragraph in docs/nagas.md:
--
--   * models/terrain.lua says `deep` is unwalkable and drowns. That is data, and data cannot be wrong
--     on its own -- it can only be ignored.
--   * models/combat.lua opens it to a swimmer and carries a SHOVE into it. Those are two different
--     functions (moveGraph's legality test, footprintCanShift's) that have to disagree about the same
--     tile in exactly the right way, and nothing in the terrain table would notice if one drifted.
--   * models/hazard.lua has to be willing to STAND a zone on ground nothing can stand on -- the one
--     refusal that, left alone, would have shipped this entire feature dead and silent: every channel
--     tile would hand over a hazard spec and every one would be dropped on the floor.
--
-- And the fourth claim is the one that matters most and is the easiest to lose in a refactor: a
-- drowned COMPANION still walks home. docs/the-count.md's law is that a bad trip costs a body on the
-- bench and never a character, and a terrain type that could permanently delete a roster member would
-- break it from underneath -- quietly, in one flag, with every other test in the tree still green.

local Terrain = require("models.terrain")
local Arena = require("models.arena")
local Combat = require("models.combat")
local Character = require("models.character")
local Item = require("models.item")
local Hazard = require("models.hazard")

-- A board of open ground with `cells` re-laid as `kind`. Copies EVERY property the hydrator copies
-- (models/arena.lua), `swim` and `drowns` included -- a helper that dropped them would test a tile
-- that does not exist.
local function board(cols, rows, kind, cells)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    local def = Terrain.get(kind)
    for _, c in ipairs(cells or {}) do
        tiles[c.y][c.x] = { type = kind, moveCost = def.moveCost, walkable = def.walkable,
                            sightCost = def.sightCost, bonus = def.bonus, tags = def.tags,
                            swim = def.swim, drowns = def.drowns }
    end
    -- ...AND IT STANDS THE GROUND'S OWN ZONES, because a real board does (Arena.terrainZones, spent
    -- through withTerrainZones at build time) and a test board that did not would be testing a channel
    -- with no drowning in it. The first cut of this helper skipped them and the shove case below
    -- cheerfully reported that a body carried into deep water was fine -- which is exactly the shape of
    -- bug this spec exists to catch, arriving in the spec itself.
    local hazards = {}
    for y = 1, rows do
        for x = 1, cols do
            local spec = Arena.TERRAIN_ZONES[tiles[y][x].type]
            if spec then
                hazards[#hazards + 1] = { id = spec.id, x = x, y = y, duration = spec.duration }
            end
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, hazards = hazards,
             objective = { type = "killAll" } }
end

local function body(itemIds, x, y, id)
    local char = Character.instantiate(id or "character_rowan")
    char.inventory = {}
    for _, itemId in ipairs(itemIds or {}) do Character.addItem(char, Item.instantiate(itemId)) end
    char.stats.movement = 8
    return { char = char, x = x or 3, y = y or 5 }
end

-- A channel across y3 of a 6x6 board: over it, through it, or nowhere.
local function channel()
    local cells = {}
    for x = 1, 6 do cells[#cells + 1] = { x = x, y = 3 } end
    return cells
end

return {
    {
        name = "deep water is solid ground that drowns; the ford is neither",
        fn = function()
            local deep = Terrain.TYPES.deep
            assert(deep, "the tile exists")
            assert(deep.walkable == false, "deep water is unwalkable -- every carve and guard reads it")
            assert(deep.drowns == true, "and it drowns")
            assert(deep.swim == true, "a swimmer belongs in it")
            assert(deep.sightCost == 0, "you see across water and shoot across it")

            local ford = Terrain.TYPES.water
            assert(ford.walkable == true, "the ford stays wadeable by anybody")
            assert(ford.swim == true, "and a swimmer is at home there too")
            assert(not ford.drowns, "but the shallows do not kill -- that is the whole difference")

            -- The one property that cannot be read off the table: nothing ELSE drowns. A second
            -- drowning tile is a re-tier of a lethal mechanic, not a line in a table.
            local drowning = {}
            for name, def in pairs(Terrain.TYPES) do
                if def.drowns then drowning[#drowning + 1] = name end
            end
            assert(#drowning == 1 and drowning[1] == "deep",
                "exactly one tile in the game kills you, got: " .. table.concat(drowning, ", "))
        end,
    },
    {
        -- The mirror of terrain_spec's flier case, and deliberately so: the two rules are the same
        -- shape read at the same two chokepoints, and if one is ever tightened without the other this
        -- is what says so.
        name = "a swimmer crosses deep water and a walker cannot even enter it",
        fn = function()
            local cells = channel()

            local cWalk = Combat.new(board(6, 6, "deep", cells), { body() }, {})
            local onFoot = Combat.reachable(cWalk, cWalk.units[1])
            assert(onFoot["3,4"], "the walker moves freely on its own side")
            assert(not onFoot["3,3"], "and CANNOT step into the channel -- there is no way to misclick it")
            assert(not onFoot["3,1"], "nor reach the far bank")

            local cSwim = Combat.new(board(6, 6, "deep", cells),
                { body({ "utility_gillscale_wrap" }) }, {})
            local u = cSwim.units[1]
            assert(Combat.isAquatic(u), "the Wrap is what opens it")
            local afloat = Combat.reachable(cSwim, u)
            assert(afloat["3,3"], "a swimmer may stop in the channel itself")
            assert(afloat["3,1"], "and crosses to the far bank")
        end,
    },
    {
        name = "a swimmer pays one in water, and pays its own way on land",
        fn = function()
            -- A ford at (3,4) and rough ground at (4,5): the first is free to a swimmer, the second
            -- is not. This is the clause that keeps the tag a LANE rather than a map -- a swimmer on
            -- dry ground is an ordinary body, which is the whole difference from the Zephyr Striders.
            local b = board(6, 6, "water", { { x = 3, y = 4 } })
            local rough = Terrain.get("rough")
            b.tiles[5][4] = { type = "rough", moveCost = rough.moveCost, walkable = true,
                              sightCost = rough.sightCost, bonus = rough.bonus }

            local dry = Combat.new(b, { body(nil, 3, 5) }, {})
            local wet = Combat.new(b, { body({ "utility_gillscale_wrap" }, 3, 5) }, {})

            local a = Combat.reachable(dry, dry.units[1])
            local c = Combat.reachable(wet, wet.units[1])
            assert(a["3,4"].cost == 2, "the ford costs two to wade")
            assert(c["3,4"].cost == 1, "and one to swim")
            assert(a["4,5"].cost == 2 and c["4,5"].cost == 2,
                "broken ground charges the swimmer exactly what it charges anybody")
        end,
    },
    {
        -- THE FEATURE. Everything above is the setup for this case.
        name = "a shove does not stop at the bank, and what goes in does not come out",
        fn = function()
            local c = Combat.new(board(6, 6, "deep", { { x = 3, y = 3 } }),
                { body(nil, 3, 5) }, { body(nil, 3, 4, "character_bandit") })
            local shover, victim = c.units[1], c.units[2]

            -- The preview first: the ghost has to land where the blow will put the body, or the
            -- player is shown a shove stopping on the bank while the live one drowns them.
            local px, py = Combat.knockbackTile(c, shover, victim, 1)
            assert(px == 3 and py == 3, "the preview carries the shove into the channel")

            local moved = Combat.knockback(c, shover, victim, 1)
            assert(moved == 1, "the shove carried rather than slamming into the bank")
            assert(not victim.alive, "and the channel took it")
            assert(victim.sank, "it went under rather than falling over")
            assert(not victim.corpse, "there is no body on the water to harvest")
            assert(not victim.incapacitated, "and no window for anybody to reach it through")
        end,
    },
    {
        name = "an unwalkable tile that does NOT drown still stops a shove dead",
        fn = function()
            -- The other half of the exception, and the one that keeps it an exception: a mace still
            -- slams a foe into a rock face. If this ever passes a body into a mountain, the clause in
            -- footprintCanShift has been widened past the argument that justifies it.
            local c = Combat.new(board(6, 6, "mountain", { { x = 3, y = 3 } }),
                { body(nil, 3, 5) }, { body(nil, 3, 4, "character_bandit") })
            local shover, victim = c.units[1], c.units[2]

            local moved = Combat.knockback(c, shover, victim, 1)
            assert(moved == 0, "the shove is stopped by the rock face")
            assert(victim.x == 3 and victim.y == 4, "and the body has not moved")
            assert(victim.alive or victim.corpse,
                "whatever the collision did to it, it did not sink into a mountain")
        end,
    },
    {
        name = "a swimmer and a flier are both shoved into the channel and both live",
        fn = function()
            for _, kit in ipairs({ "utility_gillscale_wrap", "utility_zephyr_striders" }) do
                local c = Combat.new(board(6, 6, "deep", { { x = 3, y = 3 } }),
                    { body(nil, 3, 5) },
                    { body({ kit }, 3, 4, "character_bandit") })
                local shover, victim = c.units[1], c.units[2]
                Combat.knockback(c, shover, victim, 1)
                assert(victim.x == 3 and victim.y == 3, kit .. ": the shove still carried")
                assert(victim.alive, kit .. ": and the water did not take it")
                assert(not victim.sank, kit .. ": nothing went under")
            end
        end,
    },
    {
        -- docs/the-count.md's law, held against a tile that would otherwise break it from underneath.
        name = "a drowned companion is still carried off the won board",
        fn = function()
            local c = Combat.new(board(6, 6, "deep", { { x = 3, y = 3 } }),
                { body(nil, 3, 4) }, { body(nil, 3, 6, "character_bandit") })
            local ally = c.units[1]
            ally.side = "party"

            assert(Combat.drown(c, ally), "the water takes it")
            assert(ally.sank and not ally.alive, "it went under")

            local fallen = Combat.fallenParty(c)
            assert(#fallen == 1, "a drowned body ENDED the fight down, so a loss must wound it")

            local carried = Combat.reviveFallenParty(c, 0.2)
            assert(#carried == 1, "and a win carries it home -- a trip costs a body, never a character")
            assert(ally.alive and not ally.sank, "it is back on its feet, and no longer under anything")
        end,
    },
    {
        -- THE SILENT FAILURE THIS WHOLE FEATURE WAS ONE LINE AWAY FROM. Hazard.place refuses
        -- unwalkable ground because nothing stands on a wall; deep water is unwalkable BECAUSE of what
        -- its zone does. Without the exception, Arena.terrainZones would hand over a spec per channel
        -- tile, every one would be dropped, and the tile would ship inert with nothing red anywhere.
        name = "a drowning zone stands on ground nothing can stand on",
        fn = function()
            local c = Combat.new(board(6, 6, "deep", { { x = 3, y = 3 } }), { body(nil, 3, 5) }, {})
            local h = Hazard.place(c, 3, 3, "hazard_deep_water", { duration = 9999 })
            assert(h, "the channel holds its own zone")

            -- ...and the refusal it is an exception TO is untouched.
            local m = Combat.new(board(6, 6, "mountain", { { x = 3, y = 3 } }), { body(nil, 3, 5) }, {})
            assert(not Hazard.place(m, 3, 3, "hazard_fire", { duration = 5 }),
                "a mountain still holds no hazard -- the exception is `drowns`, not `unwalkable`")
        end,
    },
    {
        name = "the fen and the flooded vault are walled with water, and their boards did not move",
        fn = function()
            assert(Arena.BIOME_TERRAIN.swamp.block == "deep", "the swamp is walled by the deep")
            assert(Arena.BIOME_TERRAIN.underworld.block == "deep", "and so is the vault under the city")

            -- THE GUARANTEE THAT MADE THIS SWAP FREE: `deep` is unwalkable exactly as `mountain` was,
            -- so the walkable print of every seeded board is bit-for-bit what it was. Asserted by
            -- rolling the same seed and comparing walkability tile for tile against a board whose
            -- blocker is put back to stone.
            for _, biome in ipairs({ "swamp", "underworld" }) do
                local now = Arena.generateLayout({ seed = 31337, party = 3, enemies = 3, biome = biome })
                local was = Arena.BIOME_TERRAIN[biome].block
                Arena.BIOME_TERRAIN[biome] = { fill = Arena.BIOME_TERRAIN[biome].fill,
                                               rise = Arena.BIOME_TERRAIN[biome].rise,
                                               block = "mountain" }
                local before = Arena.generateLayout({ seed = 31337, party = 3, enemies = 3, biome = biome })
                Arena.BIOME_TERRAIN[biome].block = was

                local moved = 0
                for y = 1, now.rows do
                    for x = 1, now.cols do
                        local a = Terrain.walkable(now.tiles[y][x])
                        local b = Terrain.walkable(before.tiles[y][x])
                        if a ~= b then moved = moved + 1 end
                    end
                end
                assert(moved == 0, biome .. ": the blocker swap moved " .. moved .. " tiles of silhouette")
            end
        end,
    },
    {
        name = "the shallows soak, and Wet is what carries the charge out of the water",
        fn = function()
            local c = Combat.new(board(6, 6, "water", { { x = 3, y = 4 } }), { body(nil, 3, 5) }, {})
            local u = c.units[1]
            Combat.enterTile(c, u, 3, 4, "walk", 3, 5)
            assert(u.statuses and #u.statuses > 0, "wading the ford soaks you")
            local wet = false
            for _, s in ipairs(u.statuses) do
                if s.id == "status_wet" then wet = true end
            end
            assert(wet, "and what it leaves is Wet")
        end,
    },
}
