-- Run one objective fight to a decision with nobody watching: the harness the objective pass owed
-- (approved 2026-10-21, "A guard that can run them").
--
-- The skirmish guard (tests/skirmish_spec.lua) drives models/autobattle.lua, which can only finish a
-- fight the model decides alone -- no waves walk on, no captive is cut free, no runner leaves. This
-- adds the three things a watched fight's checkOutcome does besides asking (states/battle.lua):
-- Waves.tick at the fight's own level, then Combat.settleObjective. And it plays the company as the
-- `objective` posture, so a crossing is walked, a post is taken and a captive is reached rather than
-- the field simply being cleared -- which is the fight the objective exists to stop being.
--
-- Returns { result = "win"|"loss"|nil, turns, escaped, freed, looted }. `result` nil is UNDECIDED: the
-- turn guard tripped, which for a fight with a clock is the worst version of the thing being guarded.
local Autobattle = require("models.autobattle")
local Combat = require("models.combat")
local Descent = require("models.descent")
local EncounterBattle = require("models.encounter_battle")
local Encounter = require("models.encounter")
local Experience = require("models.experience")
local Muster = require("models.muster")
local Player = require("models.player")
local Waves = require("models.waves")

local Run = {}

Run.SEED = 20261021

-- The first floor each biome stands on, read off the descent itself (an unshuffled run).
local FIRST_FLOOR
local function firstFloor(biome)
    if not FIRST_FLOOR then
        FIRST_FLOOR = {}
        for f = 1, Descent.FLOORS do
            local b = Descent.biomeAt(nil, f)
            FIRST_FLOOR[b] = FIRST_FLOOR[b] or f
        end
    end
    return FIRST_FLOOR[biome]
end

local GROUNDS = { "forest", "cave", "swamp", "volcanic", "tundra", "desert", "spire", "underworld" }

-- Where the game deals this fight: its own ground, on its home floor (rung 2 is the circle's seat).
function Run.placeOf(def)
    -- An adventuring party has no ground of its own: it walks every floor from its opening one down
    -- (Adventurers.openingFloor), so it is measured where it first appears, on that floor's ground.
    if def.party then
        local floor = def.depth or 1
        return Descent.biomeAt(nil, floor), floor
    end
    for _, g in ipairs(GROUNDS) do
        local f = firstFloor(g)
        if f then
            local floor = f + ((def.rung == 2) and 1 or 0)
            local ok, yes = true, true
            if def.condition then ok, yes = pcall(def.condition, { biome = g, depth = floor, rung = def.rung or 1 }) end
            if ok and yes then return g, floor end
        end
    end
    return "forest", def.depth or 1
end

-- The four the floor was priced against (Descent.COMPANY), at the level a company reaching it holds.
function Run.company(floor)
    local player = Player.new()
    player.roster = {}
    for _, id in ipairs(Descent.COMPANY) do Player.recruit(player, id) end
    for _, char in ipairs(player.roster) do
        Experience.award(char, Experience.totalFor(Descent.expectedLevel(floor)))
    end
    Player.resolveLevels(player)
    return player
end

function Run.fight(id, opts)
    opts = opts or {}
    local def = Encounter.get(id)
    local biome, floor = Run.placeOf(def)
    floor = opts.floor or floor
    local player = Run.company(floor)
    if love and love.math and love.math.setRandomSeed then love.math.setRandomSeed(Run.SEED)
    else math.randomseed(Run.SEED) end
    local enemyLevel = Descent.dangerLevel({ floor = floor })
    local built = EncounterBattle.build({
        -- `opts.dressing`: a rolled dressing (models/dressing.lua) to play the fight in -- a rolled
        -- objective kind, affixes, a condition -- exactly as the map would have stamped it.
        encounter = { id = id, kind = def.kind, dressing = opts.dressing },
        biome = biome, depth = floor, rung = def.rung, enemyLevel = enemyLevel,
        party = player.roster, seed = opts.seed or Run.SEED,
    })
    local combat = built.combat
    EncounterBattle.autoDeploy(combat, built.arena, Muster.fielded(player))
    Combat.openBattle(combat)
    for _, u in ipairs(combat.units) do
        if u.side == "party" and Combat.isPlayerControlled(u) then u.postureOverride = "objective" end
    end
    local ctx = { depth = floor, biome = biome, rung = def.rung }
    local grow = { level = enemyLevel }
    local result, turns = Autobattle.run(combat, {
        maxTurns = opts.maxTurns or 400,
        between = function(c)
            Waves.tick(c, ctx, grow)
            Combat.settleObjective(c)
        end,
    })
    return {
        result = result, turns = turns, combat = combat, built = built, floor = floor, biome = biome,
        escaped = combat.escaped ~= nil, freed = combat.captiveFreed == true,
        looted = combat.heapsLooted or 0,
    }
end

return Run
