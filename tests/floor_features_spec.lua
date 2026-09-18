-- WHAT A FLOOR ASKS ITS GENERATOR FOR, AND WHETHER ANYBODY PASSES IT ON.
--
-- THIS FILE EXISTS BECAUSE A WEEK OF WORK WAS INVISIBLE. Five params were added to Descent.floorQuest's
-- map over one week -- the traps, the wired chests, the side locks, the holes and the set-pieces. Each
-- one had a model, a generator pass and its own spec. None of them was in a floor anybody could walk.
--
-- The reason is that THREE separate places build an Overworld.generate params table by copying that map
-- field by field -- states/game.lua, tools/board_report.lua and tools/board_render.lua -- and not one of
-- the three learned the new names. The tools drew and measured a board with none of it on; the game
-- generated one.
--
-- The specs could not see it either, and that is the part worth keeping in mind: every one of them
-- drove Overworld.generate with its own params, which tests the GENERATOR. What WIRES a floor to the
-- generator is a different question, and it had three answers that all had to be right.
--
-- So: one declared list (Descent.FLOOR_FEATURE_KEYS), one copier, and these cases, which fail the day a
-- sixth param is added to a floor without being named in it.

local Descent = require("models.descent")
local Player = require("models.player")

-- Everything on a floor's map that is NOT a feature param: the geometry, the stop budget, the ends, and
-- the descriptor fields the state reads directly. Listed so the case below can say "everything else
-- must be declared" rather than "these five must be declared", which is the assertion that actually
-- catches a sixth.
local NOT_A_FEATURE = {
    biome = true, cols = true, rows = true, encounters = true, encounterCount = true,
    cacheCount = true, keyCount = true, ascent = true, exitAtStart = true, secrets = true,
    objective = true, objectives = true, combatShare = true, combatBudget = true,
    eliteShare = true, guarantee = true, guaranteeKinds = true, houseMaterials = true,
    spacing = true, carve = true, layout = true, seed = true, visionRadius = true,
    tileSize = true, braid = true, descent = true, floorLevel = true, dangerLevel = true,
}

return {
    { name = "every non-geometry param a floor asks for is in the declared list", fn = function()
        local player = Player.new()
        local run = Descent.new(player, 4242)
        local unknown = {}
        local declared = {}
        for _, k in ipairs(Descent.FLOOR_FEATURE_KEYS) do declared[k] = true end

        for floor = 1, Descent.FLOORS do
            run.floor = floor
            for key in pairs(Descent.floorQuest(run, player).map) do
                if not NOT_A_FEATURE[key] and not declared[key] then unknown[key] = true end
            end
        end

        local names = {}
        for k in pairs(unknown) do names[#names + 1] = k end
        table.sort(names)
        assert(#names == 0,
            "a floor asks for " .. table.concat(names, ", ") .. " and nothing carries it to the "
            .. "generator. Add it to Descent.FLOOR_FEATURE_KEYS (and to NOT_A_FEATURE here if it is "
            .. "geometry rather than a feature). This is the exact failure that hid the traps, the "
            .. "locks, the holes and the vaults from every floor for a week.")
    end },

    { name = "the copier carries every declared key, and invents none", fn = function()
        local mp = {}
        for i, k in ipairs(Descent.FLOOR_FEATURE_KEYS) do mp[k] = "sentinel" .. i end
        local params = Descent.applyFloorFeatures({}, mp)

        local n = 0
        for i, k in ipairs(Descent.FLOOR_FEATURE_KEYS) do
            assert(params[k] == "sentinel" .. i, k .. " did not reach the generator's params")
            n = n + 1
        end
        local got = 0
        for _ in pairs(params) do got = got + 1 end
        assert(got == n, "the copier wrote " .. got .. " keys for " .. n .. " declared")

        -- A floor that asks for nothing gets nothing: an authored quest has no descent features and
        -- must not grow them by passing through here.
        local empty = Descent.applyFloorFeatures({}, {})
        for _ in pairs(empty) do error("the copier invented a param from an empty map") end
    end },

    { name = "EVERY PLACE THAT BUILDS GENERATOR PARAMS USES THE COPIER", fn = function()
        -- A source scan, because the thing being asserted is "nobody hand-rolled a fourth list". It is
        -- the only way to ask the question -- the three call sites are inside a state and two tools,
        -- none of which can be driven headlessly for this.
        local function source(path)
            local f = io.open(path, "r")
            assert(f, "cannot read " .. path)
            local body = f:read("*a")
            f:close()
            return body
        end

        for _, path in ipairs({ "states/game.lua", "tools/board_report.lua", "tools/board_render.lua" }) do
            local body = source(path)
            assert(body:find("applyFloorFeatures", 1, true),
                path .. " builds generator params without Descent.applyFloorFeatures -- which is how "
                .. "five features came to exist everywhere except in a floor somebody could walk")
        end

        -- ...and nobody restates the list. A second copy is a second thing to go stale, which is the
        -- whole reason the list was pulled into one place.
        for _, path in ipairs({ "tools/board_report.lua", "tools/board_render.lua" }) do
            local body = source(path)
            assert(not body:find("params.vaultCount = mp.vaultCount", 1, true),
                path .. " keeps its own copy of the feature list beside the shared one")
        end
    end },
}
