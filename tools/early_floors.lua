-- Early floors against the company a new player has: run with
--
--     & "E:\LOVE\lovec.exe" . early-floors [seeds] [floors=1-3] [only=<substring>] [verbose]
--
-- WHAT THE FIRST THREE FLOORS COST THE COMPANY THAT ACTUALLY WALKS THEM. Every other harness in the tree
-- fields Descent.COMPANY -- the four generic stand-ins (knight, priest, archer, mage) the floors were
-- PRICED against. A new save brings somebody else: the avatar (a Novice on its free first class), Rowan,
-- Xin out of the Ward and Gyeom off floor one. This builds that company the way the game does --
-- prologue.skip (which is what a played Act 0 leaves behind), the free class pick spent through
-- Class.unlock, Gyeom recruited -- levels it to Descent.expectedLevel of the floor, and fights every
-- fight the floor can deal:
--
--   * every combat and elite in Descent.floorPool (the wandering pool and the seated elites, adventuring
--     parties included), built through EncounterBattle exactly as a walk-off builds them, with the
--     floor's own quest (so floor one's Descent.OPENING_CAP applies);
--   * every end the floor carries (Descent.floorQuest's objectives: the stair first), as an objective.
--
-- Each fight runs `seeds` times (default 10) off fresh copies of the company, each body at full health
-- -- no attrition across fights is modelled, so this is the most generous reading a fight can have.
-- THE DICE ROLL: Combat.FORCE_HIT is left false (the suite pins it true; this is not the suite), so
-- accuracy, avoid and crits are live. Objective fights tick their waves and settle their objective
-- between unit-turns the way tests/support/objective_run.lua does, and the company plays the
-- `objective` posture on any fight that is not a plain kill-all.
--
-- Prints one row per fight: id, kind, floor, win rate, mean unit-turns, mean company bodies down at the
-- end (dead or incapacitated -- `alive` false), and for anything under 70% who fell most and who was
-- left standing. `verbose` also prints each trial.

local Autobattle = require("models.autobattle")
local Character = require("models.character")
local Class = require("models.class")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")
local Experience = require("models.experience")
local Item = require("models.item")
local Muster = require("models.muster")
local Player = require("models.player")
local Waves = require("models.waves")

local M = {}

M.SEED_BASE = 20261024
M.AVATAR_CLASS = "fighter"
M.FLAG = 0.70

-- The company a new save carries onto `floor`: what Act 0 leaves (prologue.skip -- the avatar, Rowan,
-- Xin, the prologue's grid grants), the avatar's free root spent on AVATAR_CLASS with its gift put in the
-- grid rather than left in the stash, and Gyeom, who joins on floor one. Then every body is brought up
-- to the level the experience curve lands a company on that floor.
local function company(floor)
    local prologue = require("states.prologue")
    local player = Player.new()
    prologue.skip(player)
    local avatar
    for _, c in ipairs(player.roster) do if c.id == Class.AVATAR_ID then avatar = c end end
    local ok, gift = Class.unlock(player, avatar, M.AVATAR_CLASS)
    assert(ok, "the free first pick refused: " .. tostring(gift))
    if gift then
        -- Out of the stash and into the hand: a player who just picked a class wears its gift.
        for i, item in ipairs(player.stash or {}) do
            if item.id == gift then
                if Character.addItem(avatar, Item.instantiate(gift)) then table.remove(player.stash, i) end
                break
            end
        end
    end
    Player.recruit(player, "character_gyeom")
    local joins = require("models.conversation").pendingJoins
    for i = #joins, 1, -1 do joins[i] = nil end

    local want = Experience.totalFor(Descent.expectedLevel(floor))
    for _, char in ipairs(player.roster) do
        if (char.xp or 0) < want then Experience.award(char, want - (char.xp or 0)) end
    end
    Player.resolveLevels(player)
    Player.restore(player)
    return player
end

local function fightsOn(floor)
    local run = Descent.new(nil, M.SEED_BASE + floor)
    run.floor = floor
    local dq = Descent.floorQuest(run)
    local mp = dq.map
    -- The ctx states/game.lua builds: the RUNG is what puts a circle's second floor on its own elites
    -- (models/encounter.lua) -- without it every floor reads as its circle's approach.
    local pool = Descent.floorPool({ biome = mp.biome, prestige = 10, quest = dq, depth = floor,
        rung = Descent.floorWithinCircle(floor) })
    local list = {}
    local objs = mp.objectives or { mp.objective }
    for i, spec in ipairs(objs) do
        list[#list + 1] = { id = (i == 1 and "STAIR " or "END ") .. tostring(spec.name), kind = "objective",
            spec = spec, floor = floor, dq = dq }
    end
    local seen = {}
    table.sort(pool, function(a, b) return tostring(a.id) < tostring(b.id) end)
    for _, e in ipairs(pool) do
        if (e.kind == "combat" or e.kind == "elite") and (e.weight or 1) > 0 and not seen[e.id] then
            seen[e.id] = true
            local def = Encounter.get(e.id) or {}
            list[#list + 1] = { id = e.id, kind = def.party and "party" or e.kind, encKind = e.kind,
                weight = e.weight, floor = floor, dq = dq }
        end
    end
    return list, dq
end

local function nameOf(u) return (u.char and (u.char.name or u.char.id)) or "?" end

local function trial(f, seed)
    local player = company(f.floor)
    math.randomseed(seed)
    if love and love.math and love.math.setRandomSeed then love.math.setRandomSeed(seed) end
    local dq = f.dq
    local rung = Descent.floorWithinCircle(f.floor)
    local built = EncounterBattle.build({
        encounter = { id = f.kind ~= "objective" and f.id or nil, kind = f.encKind or f.kind },
        objective = f.spec, quest = dq,
        biome = dq.map.biome, depth = f.floor, rung = rung,
        enemyLevel = dq.dangerLevel, floorLevel = dq.floorLevel,
        party = player.roster, seed = seed,
    })
    local combat = built.combat
    EncounterBattle.autoDeploy(combat, built.arena, Muster.fielded(player))
    Combat.openBattle(combat)
    local obj = combat.objective
    local plain = not obj or obj.type == nil or obj.type == "killAll"
    if not plain then
        for _, u in ipairs(combat.units) do
            if u.side == "party" and Combat.isPlayerControlled(u) then u.postureOverride = "objective" end
        end
    end
    local ctx = { depth = f.floor, biome = dq.map.biome, rung = rung, quest = dq }
    local grow = { level = dq.dangerLevel, floor = dq.floorLevel }
    local result, turns = Autobattle.run(combat, {
        maxTurns = 400,
        between = function(c)
            Waves.tick(c, ctx, grow)
            Combat.settleObjective(c)
        end,
    })
    local down, fell, standing, foes = 0, {}, {}, 0
    for _, u in ipairs(combat.units) do
        if u.side == "party" and Combat.isPlayerControlled(u) then
            if not u.alive then down = down + 1; fell[#fell + 1] = nameOf(u) end
        elseif u.side ~= "party" then
            foes = foes + 1
            if u.alive then standing[#standing + 1] = nameOf(u) end
        end
    end
    return { result = result, turns = turns, down = down, fell = fell, standing = standing, foes = foes,
        objType = obj and obj.type or "killAll" }
end

function M.run(args)
    args = args or {}
    local seeds, lo, hi, only, verbose = 10, 1, 3, nil, false
    for _, a in ipairs(args) do
        a = tostring(a)
        if tonumber(a) then seeds = tonumber(a) end
        local x, y = a:match("^floors=(%d+)-(%d+)$"); if x then lo, hi = tonumber(x), tonumber(y) end
        local o = a:match("^only=(.+)$"); if o then only = o end
        if a == "verbose" then verbose = true end
    end
    Combat.FORCE_HIT = false

    print(string.format("EARLY FLOORS -- floors %d-%d, %d seeds a fight, dice live, avatar on %s", lo, hi,
        seeds, M.AVATAR_CLASS))
    for floor = lo, hi do
        local p = company(floor)
        local parts = {}
        for _, c in ipairs(p.roster) do
            local items = {}
            for _, it in ipairs(Character.eachItem(c)) do items[#items + 1] = it.id end
            parts[#parts + 1] = string.format("%s L%d [%s]", c.name or c.id, c.level or 1, table.concat(items, " "))
        end
        local dq = select(2, fightsOn(floor))
        print(string.format("  floor %d (%s, %s): enemies at %d, floor level %d", floor, tostring(dq.sin),
            dq.map.biome, dq.dangerLevel, dq.floorLevel))
        for _, s in ipairs(parts) do print("    " .. s) end
    end
    print("")
    print(string.format("  %-44s %-9s %5s %6s %7s %6s %6s  %s", "fight", "kind", "floor", "win", "turns",
        "down", "weight", "objective"))

    local flagged = {}
    for floor = lo, hi do
        local list = fightsOn(floor)
        for _, f in ipairs(list) do
            if not only or tostring(f.id):find(only, 1, true) then
                local wins, turns, down, stalls = 0, 0, 0, 0
                local fellCount, standCount, objType = {}, {}, nil
                for s = 1, seeds do
                    local ok, r = pcall(trial, f, M.SEED_BASE + s * 7919 + floor)
                    if not ok then
                        print(string.format("  %-44s ERROR %s", tostring(f.id), tostring(r)))
                        break
                    end
                    objType = r.objType
                    if r.result == "win" then wins = wins + 1 end
                    if r.result == nil then stalls = stalls + 1 end
                    turns, down = turns + r.turns, down + r.down
                    for _, n in ipairs(r.fell) do fellCount[n] = (fellCount[n] or 0) + 1 end
                    if r.result ~= "win" then
                        for _, n in ipairs(r.standing) do standCount[n] = (standCount[n] or 0) + 1 end
                    end
                    if verbose then
                        print(string.format("      seed %d: %s in %d, down %d [%s], left standing [%s]", s,
                            tostring(r.result), r.turns, r.down, table.concat(r.fell, ", "),
                            table.concat(r.standing, ", ")))
                    end
                end
                local rate = wins / seeds
                print(string.format("  %-44s %-9s %5d %5.0f%% %7.1f %6.2f %6s  %s%s", tostring(f.id), f.kind,
                    floor, rate * 100, turns / seeds, down / seeds,
                    f.weight and string.format("%.2f", f.weight) or "-", tostring(objType),
                    stalls > 0 and string.format("  (%d undecided at 400)", stalls) or ""))
                if rate < M.FLAG then
                    flagged[#flagged + 1] = { f = f, rate = rate, fell = fellCount, stand = standCount }
                end
            end
        end
    end

    print("")
    print(string.format("UNDER %d%%: %d fight(s)", M.FLAG * 100, #flagged))
    local function top(t)
        local rows = {}
        for k, v in pairs(t) do rows[#rows + 1] = { k = k, v = v } end
        table.sort(rows, function(a, b) return a.v > b.v or (a.v == b.v and a.k < b.k) end)
        local out = {}
        for i = 1, math.min(6, #rows) do out[#out + 1] = rows[i].k .. " x" .. rows[i].v end
        return table.concat(out, ", ")
    end
    for _, x in ipairs(flagged) do
        print(string.format("  %s (floor %d, %.0f%%)", tostring(x.f.id), x.f.floor, x.rate * 100))
        print("    company fallen: " .. top(x.fell))
        print("    standing after a loss: " .. top(x.stand))
    end
end

return M
