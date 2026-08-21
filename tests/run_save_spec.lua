-- Tests for RUN persistence: the active overworld traversal saved so quitting mid-quest and choosing
-- Continue drops the player back onto the map where they left off (models/overworld.lua snapshot/
-- fromSnapshot, models/save.lua snapshotRun/restoreRun, and the player-level round trip). Everything is
-- driven through the real serializer (Save.encode -> Save.decode), so a value the encoder can't handle --
-- a function or love object leaking onto a cell -- fails here rather than in a player's save. Pure, headless.

local Overworld = require("models.overworld")
local Save = require("models.save")
local Player = require("models.player")
local Descent = require("models.descent")

-- A small deterministic board with an objective, a key/gate, and mixed encounters.
local function genGrid()
    return Overworld.generate({
        cols = 25, rows = 17, seed = 42, biome = "forest",
        encounterCount = 4, keyCount = 1, objective = { name = "Boss" },
        encounters = { { kind = "combat", weight = 3 }, { kind = "treasure", weight = 1 } },
    })
end

-- Push any plain-data table through the exact serializer a real save uses, so the round trip proves the
-- data survives encoding (not merely a shared reference).
local function reserialize(data)
    return Save.decode("return " .. Save.encode(data, 0))
end

-- Tile + encounter-kind signature, to compare two grids cell-for-cell.
local function signature(grid)
    local parts = {}
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid:get(x, y)
            parts[#parts + 1] = (c.tile or "-") .. ":" .. (c.encounter and c.encounter.kind or "-")
        end
    end
    return table.concat(parts, "|")
end

return {
    {
        name = "a grid round-trips through snapshot/fromSnapshot with its geometry and stops intact",
        fn = function()
            local g = genGrid()
            local g2 = Overworld.fromSnapshot(reserialize(g:snapshot()))

            assert(g2.cols == g.cols and g2.rows == g.rows, "dimensions survive")
            assert(g2.tilesetId == g.tilesetId, "tileset survives (so the renderer re-resolves its art)")
            assert(g2.tilesetDef, "tilesetDef is re-resolved on restore, not serialized")
            assert(g2.start.x == g.start.x and g2.start.y == g.start.y, "the start cell survives")
            assert(g2.objective.x == g.objective.x and g2.objective.y == g.objective.y,
                "the objective cell survives")
            assert(#g2.keyIds == #g.keyIds, "the required-key list survives")
            assert(signature(g2) == signature(g), "every tile and encounter marker survives the round trip")
            -- Rebuilt cells carry their own indices (dropped on snapshot, restored from position).
            assert(g2:get(3, 4).x == 3 and g2:get(3, 4).y == 4, "cell x/y are rebuilt from position")
        end,
    },
    {
        name = "fog, cleared stops and picked keys (the mutable run state) survive the round trip",
        fn = function()
            local g = genGrid()
            g:objectiveCell().cleared = true
            g:startCell().seen = true
            local other = g:get(g.start.x, g.start.y + 1)
            other.picked = true

            local g2 = Overworld.fromSnapshot(reserialize(g:snapshot()))
            assert(g2:objectiveCell().cleared == true, "a cleared objective stays cleared")
            assert(g2:startCell().seen == true, "a revealed tile stays revealed (fog is not re-fogged)")
            assert(g2:get(g.start.x, g.start.y + 1).picked == true, "a lifted key stays lifted")
        end,
    },
    {
        name = "a run round-trips its quest, position, keys and companion scratch",
        fn = function()
            local g = genGrid()
            g:objectiveCell().cleared = true
            local run = {
                questId = "quest_bastion_slot_01",
                day = 3,
                grid = g,
                -- snapshotRun only reads px/py/keysHeld off the map widget; a stand-in table is enough.
                map = { px = g.start.x + 1, py = g.start.y, keysHeld = { key1 = true } },
                abilityState = { character_rowan = { vigils = 2 } },
            }

            local restored = Save.restoreRun(reserialize(Save.snapshotRun(run)))
            assert(restored, "the run restores")
            assert(restored.quest and restored.quest.id == "quest_bastion_slot_01",
                "the quest is rehydrated from its id")
            assert(restored.quest.map and restored.quest.map.objective, "the rehydrated quest carries its map")
            assert(restored.day == 3, "the launch day survives -- a resumed run must not re-read the clock")
            assert(restored.px == g.start.x + 1 and restored.py == g.start.y, "the token position survives")
            assert(restored.keysHeld.key1 == true, "a held key survives")
            assert(restored.abilityState.character_rowan.vigils == 2, "banked overworld scratch survives")
            assert(restored.grid:objectiveCell().cleared == true, "the board's cleared state rides along")
        end,
    },
    {
        name = "a wounded company's resource pools ride on the run (a resume is not a free heal)",
        fn = function()
            local player = Player.new()
            local char = player.roster[1]
            local hp = char.stats and char.stats.health
            assert(type(hp) == "table", "the test character has a health pool")
            hp.current = 1 -- wound them

            local g = genGrid()
            player.activeRun = {
                questId = "quest_bastion_slot_01", day = 1, grid = g,
                map = { px = g.start.x, py = g.start.y, keysHeld = {} }, abilityState = {},
            }

            local restored = Save.restore(reserialize(Save.snapshot(player)))
            assert(restored.resumeRun, "the run round-trips")
            local pools = restored.resumeRun.resources[char.id]
            assert(pools and pools.health == 1,
                "the wounded HP is carried on the run, not silently reloaded to full")
        end,
    },
    {
        name = "resource pools are NOT stored when there is no run (the hub still heals)",
        fn = function()
            local player = Player.new()
            local hp = (player.roster[1].stats or {}).health
            if type(hp) == "table" then hp.current = 1 end -- wounded, but not in a run

            local restored = Save.restore(reserialize(Save.snapshot(player)))
            assert(restored.resumeRun == nil, "no run means no resume descriptor -- and no persisted wounds")
        end,
    },
    {
        name = "a run naming a quest no longer in data/ is dropped (resume at the hub, don't crash)",
        fn = function()
            local restored = Save.restoreRun({
                questId = "quest_that_was_deleted_zzz",
                grid = genGrid():snapshot(),
            })
            assert(restored == nil, "an unknown quest id yields no run")
        end,
    },
    {
        name = "an active run round-trips a whole player into a resume descriptor",
        fn = function()
            local player = Player.new()
            local g = genGrid()
            player.activeRun = {
                questId = "quest_bastion_slot_01",
                day = 2,
                grid = g,
                map = { px = g.start.x, py = g.start.y, keysHeld = {} },
                abilityState = {},
            }

            local restored = Save.restore(reserialize(Save.snapshot(player)))
            assert(restored, "the player restores")
            assert(restored.resumeRun, "an active run becomes a resume descriptor on load")
            assert(restored.resumeRun.quest.id == "quest_bastion_slot_01", "the resumed quest is named")
            assert(restored.resumeRun.px == g.start.x, "the resume position survives the player round trip")
        end,
    },
    {
        name = "a save with no run resumes at the hub (no resume descriptor invented)",
        fn = function()
            local restored = Save.restore(reserialize(Save.snapshot(Player.new())))
            assert(restored.resumeRun == nil, "a player who never entered a run carries no resume descriptor")
        end,
    },
    {
        -- THE BUG THIS HOLDS THE FLOOR ON. Save.restoreRun runs inside Save.load, before there is a
        -- player object to hand it, so the floor descriptor it rebuilds is a stair and nothing else
        -- (Descent.floorObjectives answers a nil player that way). The BOARD, meanwhile, comes back off
        -- the snapshot with every errand cell intact. states/game.lua matches a cell to its spec by
        -- questId and falls back to objectives[1] when nothing matches -- so before the fix an errand
        -- tile on a resumed floor resolved to the stair: the scene that asks whether to take the house's
        -- work never played, and the fight the tile opened was the guardian's rather than the house's.
        --
        -- Asserted against a RE-SYNTHESIZED descriptor, which is what states/game.lua's enter now builds
        -- from `resume.descent` and the live player. The lookup below is objectiveAt's, spelled out.
        name = "a resumed descent floor still knows whose work each of its ends is",
        fn = function()
            local player = Player.new()
            local run = Descent.new(player)
            player.descentRun = run
            local quest = Descent.floorQuest(run, player)
            local mp = quest.map

            local errands = 0
            for _, spec in ipairs(mp.objectives or {}) do
                if spec.questId then errands = errands + 1 end
            end
            assert(errands > 0, "floor one seats no house work at all, so this proves nothing")

            local g = Overworld.generate({
                cols = mp.cols, rows = mp.rows, biome = mp.biome, seed = 7,
                objective = mp.objective, objectives = mp.objectives,
                layout = mp.carve, spacing = mp.spacing, ascent = mp.ascent,
                encounterCount = { min = 4, max = 4 },
                encounters = { { kind = "combat", weight = 1 } },
            })
            player.activeRun = {
                questId = quest.id,
                day = 1,
                descent = run,
                grid = g,
                map = { px = g.start.x, py = g.start.y, keysHeld = {} },
                abilityState = {},
            }

            local restored = Save.restore(reserialize(Save.snapshot(player)))
            local resume = restored and restored.resumeRun
            assert(resume and resume.descent, "the descent run survives the round trip")

            -- What states/game.lua's enter does with it: the floor read against the live player again.
            local rebuilt = Descent.floorQuest(resume.descent, player).map
            local seen = 0
            for _, o in ipairs(resume.grid.objectives or {}) do
                local cell = resume.grid:get(o.x, o.y)
                local id = cell.encounter and cell.encounter.questId
                if id then
                    local match
                    for _, spec in ipairs(rebuilt.objectives or {}) do
                        if spec.questId == id then match = spec end
                    end
                    assert(match, "the resumed floor has no spec for the work standing at "
                        .. o.x .. "," .. o.y .. " (" .. id .. "): it would fall back to the stair")
                    seen = seen + 1
                end
            end
            assert(seen == errands, "the resumed board lost an end: " .. seen .. " of " .. errands)
        end,
    },
}
