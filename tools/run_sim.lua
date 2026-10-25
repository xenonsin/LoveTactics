-- The run simulator: run with
--
--     & "E:\LOVE\lovec.exe" . run-sim [runs=3] [saves=5] [seed=S] [verbose]
--
-- WHAT THE FIRST FEW DESCENTS OF A FRESH SAVE ACTUALLY COST, played end to end rather than fight by fight.
-- tools/early_floors.lua fields the real starting company against every fight floors 1-3 can deal, each
-- at full health; this walks the LOOP that company lives in, carrying what the loop carries:
--
--   * A fresh save: Player.new with the prologue skipped (prologue.skip -- what a played Act 0 leaves),
--     the avatar's free root class spent (AVATAR_CLASS, its gift put in the hand), the save seeded `seed`.
--   * Each run is the Gate's own sequence (states/gate.lua): Descent.new(player) -- so the run's seed is
--     folded off the save exactly as the game folds it (Seed.run) -- the opening purse, then the real
--     states/game.lua entered on floor 1. THE OVERWORLD IS THE GAME'S OWN CODE: game.enter rolls the floor,
--     game.map:step walks it (so the real prowl meter deals wandering fights), game:openEncounter
--     resolves every stop, landing, stair, chest, errand and relic exactly as it does on screen.
--   * Only the SCREEN is replaced. Every pop-up panel's constructor is swapped for a stub that records its
--     options, and the POLICY below answers it; states/battle.lua is swapped for a headless twin
--     (SimBattle) that builds the fight through EncounterBattle exactly as Battle.enter does, plays it
--     through models/autobattle.lua with the dice live (Combat.FORCE_HIT off), ticks waves and settles
--     objectives between unit-turns the way battle.lua's resolveAdvance does, and then does the win /
--     loss / smoke bookkeeping battle.lua's win(), lose(), smokeOut() and finishBattle() do (xp, bonds,
--     class deeds, spoils, the fallen and the spent) before handing back to game.lua's own onWin/onLoss.
--     Conversations are skipped (every scene "accepts"). Saving is switched off. Sound is muted.
--   * Between runs, the city's bookkeeping that the loop reads: game.lua's own exits already did
--     Gate.homecoming (counted trips, the Ward's rest ticking); the hub's Player.restore runs; then the
--     Ward per policy, then the Gate's packing per policy. Hiring, shelves, forging, the Touchstone and
--     class unlocks past the free first one are NOT simulated.
--   * THE GOLD BREAKDOWN closes every report: each coin the runs earned, named by the faucet that paid
--     it, across all saves, per run and per floor band (see "The gold ledger" below).
--
-- THE ROUTE is floor_fights.lua's TOUR, against the game's own walk: greedy nearest-unvisited over every
-- seated fight, chest, supply cache, key, camp, reliquary, event, errand and crossroads, the stair last.
-- It knows the whole board (no fog) and steps tile by tile with game.map:step, preferring paths that do
-- not cross an unvisited stop. Altars, weeping stones, the road merchant, anvils, maws and the bad ground
-- (holes, dark, spinners, translations) are not walked to -- the policy would decline them.
--
-- SEEDED, BUT NOT BIT-FOR-BIT REPEATABLE ACROSS PROCESSES. math.random and love.math are seeded per
-- save, every fight's arena (the walk-off's too, via Arena.randomSeed) is folded off the save seed and
-- the fight's index, and the floors, the route and the policy's choices are pure functions of the seed.
-- But this LuaJIT (2.1.1700008891) randomises `pairs` order per process -- string keys included -- and
-- the combat engine has float sums and tie-breaks that ride it: the first divergence measured was a Stun
-- expiring a tick earlier in one process than in another. So two invocations with the same seed agree on
-- the boards and mostly on the fights, and drift where a fight sat on a knife edge. Read the table as a
-- sample, and run more saves for a steadier one.

local Character = require("models.character")
local Class = require("models.class")
local Combat = require("models.combat")
local Descent = require("models.descent")
local EncounterBattle = require("models.encounter_battle")
local Experience = require("models.experience")
local Injury = require("models.injury")
local Item = require("models.item")
local Player = require("models.player")
local Relic = require("models.relic")
local Seed = require("models.seed")

local M = {}

M.SEED_BASE = 20261025
M.AVATAR_CLASS = "fighter"

-- THE POLICY. Printed at the top of every report; change it here.
M.POLICY = {
    climbBelow = 0.35,      -- climb out the moment the expedition's health falls under this share
    afterStairBelow = 0.50, -- ...or, standing on an opened stair, under this share
    smokeDown = 2,          -- throw a Smoke when this many of the company are down...
    smokeEnemyAbove = 0.50, -- ...and the enemy side still holds more than this share of its health
    packSmokes = 2,         -- carried into each run, bought at shelf price if affordable
    packDraughts = 2,       -- healing draughts likewise
    draught = "consumable_healing_potion",
    smoke = "consumable_smoke",
    treatCost = true,       -- the Ward: pay Injury.TREAT_COST per injury while the purse allows, else rest
    maxTurns = 400,         -- a fight undecided after this many unit-turns is called a rout
    maxSteps = 1500,        -- steps on one floor before the walker gives up and climbs out
}

local function fmt(...) return string.format(...) end

-- ---------------------------------------------------------------------------
-- The harness: stubs in, stubs out
-- ---------------------------------------------------------------------------

local saved = {}
local function swap(tbl, key, value)
    saved[#saved + 1] = { tbl = tbl, key = key, value = tbl[key] }
    tbl[key] = value
end
local function restoreAll()
    for i = #saved, 1, -1 do
        local s = saved[i]
        s.tbl[s.key] = s.value
    end
    saved = {}
end

local sim -- the live simulation state (one save at a time)

local function fakeFont()
    local f = {}
    function f.getHeight() return 16 end
    function f.getWidth(_, s) return #(tostring(s or "")) * 8 end
    function f.getWrap(_, s, w)
        s = tostring(s or "")
        local lines = {}
        for line in s:gmatch("[^\n]+") do lines[#lines + 1] = line end
        return math.min(#s * 8, w or 0), lines
    end
    function f.getLineHeight() return 1 end
    function f.setLineHeight() end
    function f.setFilter() end
    function f.getAscent() return 12 end
    function f.getDescent() return 4 end
    function f.getBaseline() return 12 end
    function f.hasGlyphs() return true end
    function f.setFallbacks() end
    return f
end

-- Every pop-up the overworld can open, as a record of what it offered. The policy answers it.
local function stubPanels()
    local items = love.filesystem.getDirectoryItems("ui/panels")
    table.sort(items)
    for _, file in ipairs(items) do
        local name = file:match("^(.+)%.lua$")
        if name then
            local ok, mod = pcall(require, "ui.panels." .. name)
            if ok and type(mod) == "table" and type(mod.new) == "function" then
                swap(mod, "new", function(a, b)
                    local opts = (type(a) == "table" and a ~= mod) and a or b
                    return { simKind = name, opts = opts or {} }
                end)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The gold ledger: where every coin a run earns comes from
-- ---------------------------------------------------------------------------
--
-- EVERY GAIN IS CAUGHT AT Player.addGold, and named by WHO CALLED IT: the wrapper walks the stack to
-- the first frame outside models/player.lua and reads its file and function. That is the one seam
-- every faucet in the game pays through, so a faucet nobody listed still lands in the table -- under
-- its raw `file:function` key rather than a name, which is the point: an unlisted source is shown, not
-- hidden. The only gold written past that seam is the Gate's opening top-up (Gate.payPurse writes the
-- field directly), which is walked-in money and is tallied on its own line.
--
-- A FIGHT'S TAKINGS ARRIVE AS ONE LUMP (game.lua's grantSideSpoils, and the general's purse beside
-- Quest.complete), so EncounterBattle.spoils is wrapped too and the lump it is about to return is split
-- into its parts -- the rolled wage, the end purse, the skim, the bounty, the per-head rescue -- and
-- held until the matching addGold arrives. Both the played fight and the walk-off reach that function.

M.GOLD_BANDS = { { 1, 3 }, { 4, 6 }, { 7, 9 }, { 10, 12 }, { 13, 15 } }

-- Known callers, by `file:function` (the function name is what debug.getinfo reports; a closure in a
-- table field reads by its field name) and the gold expression on the calling line. Matched as a plain
-- prefix of the key, and, where a third entry is given, a plain suffix too.
local GOLD_NAMES = {
    { "states/game.lua:", "errand purse", ":def.rewardGold" },
    { "states/game.lua:", "guardian's set spent (gold stand-in)", ":Descent.SPENT_SET_GOLD" },
    { "models/relic.lua", "relic (Glutton's Purse and kin)" },
    { "models/item_hook.lua", "item hook between fights" },
    { "models/crossroads.lua", "crossroads dilemma" },
    { "states/game.lua:addGold:", "crossroads dilemma" }, -- the dilemma ctx's own addGold closure
    { "models/overworld_ability.lua", "road cast (gold ability)" },
    { "models/scarab.lua", "coin heap (scarab)" },
    { "models/identify.lua", "Touchstone / identify" },
    { "models/quest.lua", "quest reward" },
    { "models/request.lua", "request reward" },
    { "models/hire.lua", "hire refund" },
    { "tools/run_sim.lua", "in-fight purse (money kit)" },
}

-- The caller's source line, read once per file: it names the faucet in words that survive a line
-- shift (`def.rewardGold`, `Descent.SPENT_SET_GOLD`), where a line number would not.
local sourceLines = {}
local function lineText(src, n)
    if not sourceLines[src] then
        local t = {}
        local ok, body = pcall(love.filesystem.read, src)
        if ok and body then for line in (body .. "\n"):gmatch("([^\n]*)\n") do t[#t + 1] = (line:gsub("\r", "")) end end
        sourceLines[src] = t
    end
    local line = sourceLines[src][n or 0] or ""
    return line:match("addGold%(%s*[^,]+,%s*(.-)%)%s*[%a]*%s*$") or line:match("^%s*(.-)%s*$") or ""
end

local function goldCaller()
    for level = 3, 20 do
        local info = debug.getinfo(level, "Snl")
        if not info then break end
        local src = tostring(info.short_src or "?"):gsub("\\", "/")
        if not src:find("models/player%.lua$") then
            src = src:match("([%w_]+/[%w_]+%.lua)$") or src
            return src .. ":" .. tostring(info.name or "?") .. ":" .. lineText(src, info.currentline)
        end
    end
    return "?"
end

local function goldLabel(key)
    for _, entry in ipairs(GOLD_NAMES) do
        if key:sub(1, #entry[1]) == entry[1] and (not entry[3] or key:sub(-#entry[3]) == entry[3]) then
            return entry[2]
        end
    end
    return nil
end

local function currentFloor()
    local game = package.loaded["states.game"]
    local d = game and game.descent and Descent.depth(game.descent)
    return d or (sim and sim.run and sim.run.floor) or 0
end

local function creditGold(label, amount)
    if not (sim and sim.run) or not amount or amount == 0 then return end
    local led = sim.run.gold
    led.bySource[label] = (led.bySource[label] or 0) + amount
    local f = currentFloor()
    led.byFloor[f] = led.byFloor[f] or {}
    led.byFloor[f][label] = (led.byFloor[f][label] or 0) + amount
    led.total = led.total + amount
end

-- What kind of stop paid a fight's lump.
local function fightClass(enc)
    enc = enc or {}
    if enc.wandering then return "wandering" end
    if enc.kind == "elite" then return "elite" end
    if enc.kind == "objective" then return "stair/objective" end
    if enc.kind == "combat" then return "seated" end
    return tostring(enc.kind)
end

local function splitSpoils(opts, spoils)
    if not (spoils and (spoils.gold or 0) > 0) then return nil end
    local Spoils = require("models.spoils")
    local enc = opts.encounter or {}
    local depth = opts.floorLevel or opts.depth
    local parts, rest = {}, spoils.gold
    local function take(label, n)
        n = math.min(rest, math.max(0, math.floor(n or 0)))
        if n > 0 then parts[label] = (parts[label] or 0) + n; rest = rest - n end
    end
    local combat = opts.combat
    take("in-fight skim (Skimmer's Cut)", combat and combat.skimmed)
    take("in-fight bounty (Ledger)", combat and combat.bounty)
    local def = enc.id and require("models.encounter").get(enc.id)
    if def and def.rescue and opts.rescue then take("rescue per head", (def.rescue.gold or 0) * (opts.rescue.saved or 0)) end
    local class = fightClass(enc)
    if enc.kind == "objective" then
        take("end purse: stair/objective", Spoils.endPurse("general", depth))
    elseif not enc.rewardGold then
        take("end purse: " .. class, Spoils.endPurse(enc.kind, depth))
    end
    take("fight purse: " .. class, rest)
    return { amount = spoils.gold, parts = parts }
end

local function installGoldLedger()
    local addGold = Player.addGold
    swap(Player, "addGold", function(player, amount)
        if sim and sim.player == player and (amount or 0) > 0 then
            local key = goldCaller()
            local pend = sim.pendingSpoils
            if pend and pend.amount == amount and (key:find("^states/game%.lua") or key:find("^tools/run_sim")) then
                for label, n in pairs(pend.parts) do creditGold(label, n) end
                sim.pendingSpoils = nil
            else
                creditGold(goldLabel(key) or key, amount)
            end
        elseif sim and sim.player == player and (amount or 0) < 0 then
            sim.run.gold.spent = sim.run.gold.spent - amount
        end
        return addGold(player, amount)
    end)
    local spendGold = Player.spendGold
    swap(Player, "spendGold", function(player, amount)
        if sim and sim.run and sim.player == player and (amount or 0) > 0 then
            local key = goldCaller():match("^([^:]+:[^:]+)") or "?"
            local led = sim.run.gold
            led.spent = led.spent + amount
            led.spentBy[key] = (led.spentBy[key] or 0) + amount
        end
        return spendGold(player, amount)
    end)
    local spoilsFn = EncounterBattle.spoils
    swap(EncounterBattle, "spoils", function(opts)
        local s = spoilsFn(opts)
        if sim then sim.pendingSpoils = splitSpoils(opts or {}, s) end
        return s
    end)
    local Gate = require("models.gate")
    local payPurse = Gate.payPurse
    swap(Gate, "payPurse", function(player, amount)
        local before = (player and player.gold) or 0
        payPurse(player, amount)
        if sim and sim.run and player == sim.player then
            sim.run.gold.topUp = sim.run.gold.topUp + math.max(0, (player.gold or 0) - before)
        end
    end)
end

local function newLedger()
    return { bySource = {}, byFloor = {}, total = 0, spent = 0, spentBy = {}, topUp = 0 }
end

-- ---------------------------------------------------------------------------
-- SimBattle: states/battle.lua with nobody watching
-- ---------------------------------------------------------------------------

local SimBattle = {}

local function xpLine()
    local t = {}
    for _, c in ipairs((sim and sim.player and sim.player.roster) or {}) do t[#t + 1] = tostring(c.xp or 0) end
    return table.concat(t, "/")
end
local SMOKE = {} -- sentinel raised out of Autobattle.run when the policy throws a smoke

local function healthShare(units, side)
    local cur, max = 0, 0
    for _, u in ipairs(units) do
        if u.side == side and u.char and u.char.stats and type(u.char.stats.health) == "table" then
            local hp = u.char.stats.health
            max = max + (hp.max or 0)
            if u.alive then cur = cur + math.max(0, hp.current or 0) end
        end
    end
    return max > 0 and cur / max or 0
end

local function smokeCarrier(combat)
    if combat.smoke ~= true then return nil end
    for _, u in ipairs(combat.units) do
        if u.side == "party" and u.alive and Combat.isPlayerControlled(u) and u.char then
            for _, it in ipairs(Character.eachItem(u.char)) do
                if it.id == M.POLICY.smoke and (it.quantity or 1) > 0 then return u, it end
            end
        end
    end
    return nil
end

local function releaseParty(combat)
    for _, unit in ipairs(combat.units) do
        if unit.side == "party" then Combat.releaseClaims(unit.char) end
    end
end

function SimBattle.enter(self, opts)
    local Autobattle = require("models.autobattle")
    local Waves = require("models.waves")
    local Status = require("models.status")
    SimBattle.combat, SimBattle.fallen, SimBattle.routed = nil, nil, nil
    sim.fightIndex = sim.fightIndex + 1
    local seed = Seed.mix(sim.saveSeed, sim.fightIndex)

    local bopts = {}
    for k, v in pairs(opts) do bopts[k] = v end
    bopts.seed = seed
    local player = opts.player
    local built = EncounterBattle.build(bopts)
    local combat = built.combat
    combat.xpCeiling = opts.xpCeiling
    combat.noClassCredit = opts.classCredit == false or nil
    combat.smoke = opts.smoke
    combat.bonds = (player and opts.classCredit ~= false) and require("models.bond").snapshot(player) or nil
    combat.purse = {
        get = function() return (player and player.gold) or 0 end,
        spend = function(n)
            local have = (player and player.gold) or 0
            local take = math.max(0, math.min(math.floor(tonumber(n) or 0), have))
            if take > 0 then Player.spendGold(player, take) end
            return take
        end,
        add = function(n) Player.addGold(player, n) end,
        unit = "g",
    }
    combat.playerSide = "party"
    combat.stash = opts.stash
    combat.waveState = {}

    -- The deploy phase, committed as the player's auto-placement would (battle.lua's commitDeploy).
    local deployed, front = EncounterBattle.autoDeploy(combat, built.arena, opts.party or {})
    local resolved = opts.resolveOpening and opts.resolveOpening(deployed, front) or {}
    local traits, relicBonus = resolved.relicTraits, resolved.relicBonus
    for _, u in ipairs(combat.units) do
        if u.side == "party" and u.char then
            u.relicTraits = traits and traits[u.char] or nil
            u.meal = opts.meal
            u.relicBonus = relicBonus
        end
    end
    for _, entry in ipairs(combat.bench or {}) do
        entry.relicTraits = traits and traits[entry.char] or nil
        entry.meal, entry.relicBonus = opts.meal, relicBonus
    end
    if relicBonus then
        Combat.applyPassives(combat)
        Combat.applyUnitRules(combat)
    end
    Player.noteDeployed(player, deployed)
    Combat.openBattle(combat)
    for _, boon in ipairs(resolved.openingBoons or {}) do
        if boon.side then
            Combat.dressSide(combat, boon.side, boon.id, boon.opts)
        else
            for _, unit in ipairs(combat.units) do
                if unit.side == "party" and unit.char == boon.char and unit.alive then
                    Status.apply(combat, unit, boon.id, boon.opts)
                    break
                end
            end
        end
    end
    for _, unit in ipairs(combat.units) do
        if unit.alive and unit.char then
            for _, it in ipairs(Character.eachItem(unit.char)) do
                for _, b in ipairs(require("models.curse").openingBoons(it)) do
                    Status.apply(combat, unit, b.id, b.opts)
                end
            end
        end
    end
    -- An objective fight is played for its objective (tools/early_floors.lua does the same).
    local obj = combat.objective
    if obj and obj.type and obj.type ~= "killAll" then
        for _, u in ipairs(combat.units) do
            if u.side == "party" and Combat.isPlayerControlled(u) then u.postureOverride = "objective" end
        end
    end
    SimBattle.combat = combat

    local depth = opts.depth or 1
    local ctx = { depth = depth, rung = Descent.floorWithinCircle(depth), biome = opts.biome,
        quest = opts.quest, generalsStanding = opts.generalsStanding,
        encounterKind = opts.encounter and opts.encounter.kind,
        encounterCap = require("models.encounter").capOf(opts.encounter) }
    local grow = { level = opts.enemyLevel, floor = opts.floorLevel }
    local calls = 0
    local ok, result, turns = xpcall(function() return Autobattle.run(combat, {
        maxTurns = M.POLICY.maxTurns,
        between = function(c)
            calls = calls + 1
            if c.slippedAway then error(SMOKE) end
            -- THE POLICY'S SMOKE: two down and the other side still standing tall.
            local down = 0
            for _, u in ipairs(c.units) do
                if u.side == "party" and Combat.isPlayerControlled(u) and not u.summoned
                    and u.char and not u.alive then down = down + 1 end
            end
            if down >= M.POLICY.smokeDown and healthShare(c.units, "enemy") > M.POLICY.smokeEnemyAbove then
                local u, it = smokeCarrier(c)
                if u then
                    it.quantity = math.max(0, (it.quantity or 1) - 1)
                    c.slippedAway = u
                    error(SMOKE)
                end
            end
            Waves.tick(c, ctx, grow)
            Combat.settleObjective(c)
        end,
    }) end, function(e) if e == SMOKE then return e end return debug.traceback(e) end)
    -- THE ENGINE ITSELF CAN THROW mid-fight (a combat bug, not the sim's). Recorded with its first line
    -- and played as the company breaking off -- a rout with whoever is down -- so one crash does not end
    -- the measurement. The report counts them; a crash is a bug to file, not a balance reading.
    local crash
    if not ok and result ~= SMOKE then
        crash = tostring(result)
        result, turns = "crash", calls - 1
    elseif not ok then
        result, turns = "smoke", calls - 1
    end

    local rec = { id = opts.encounter and (opts.encounter.id or opts.encounter.name) or "?",
        kind = opts.encounter and opts.encounter.kind, floor = depth, turns = turns, result = result }
    sim.run.fights[#sim.run.fights + 1] = rec
    Combat.returnStripped(combat)
    local function report(extra)
        if not sim.verbose then return end
        local down, who = 0, {}
        for _, u in ipairs(combat.units) do
            if u.side == "party" and Combat.isPlayerControlled(u) and not u.alive then
                down = down + 1
                who[#who + 1] = tostring(u.char and u.char.name)
            end
        end
        if #who > 0 then extra = (extra or "") .. " [" .. table.concat(who, ", ") .. "]" end
        print(fmt("        fight %-34s %-9s %-5s in %3d turns, %d down%s", tostring(rec.id), tostring(rec.kind),
            tostring(rec.result), turns or 0, down, extra or "") .. (M.TRACE and (" xp " .. xpLine()) or ""))
    end

    if result == "smoke" then
        sim.run.smokes = sim.run.smokes + 1
        report()
        SimBattle.fallen = Combat.fallenParty(combat)
        SimBattle.routed = true
        releaseParty(combat)
        if opts.onLoss then opts.onLoss() end
        return
    end

    if result == "win" then
        -- battle.lua's win()
        local saved_, ofMany = Combat.protectedCount(combat)
        local rescue = { saved = saved_, of = ofMany, delvers = require("models.delver").survivors(combat) }
        if player and combat.xpByChar then Experience.resolveOnBoard(combat.units, player.roster) end
        if player and combat.bonds then
            require("models.bond").settle(player, combat.units, combat.bondDeeds)
        end
        SimBattle.fallen = Combat.reviveFallenParty(combat)
        if obj and (obj.type ~= "killAll" or combat.escaped) then Combat.rout(combat) end
        releaseParty(combat)
        -- battle.lua's finishBattle("win")
        if player then Class.bankDeeds(combat, player) end
        local paying = built.enemyUnits
        local gone = combat.escaped
        if gone then
            paying = {}
            for _, spec in ipairs(built.enemyUnits or {}) do
                if spec.char ~= gone.char then paying[#paying + 1] = spec end
            end
        end
        local spoils = EncounterBattle.spoils({
            encounter = opts.encounter, enemyUnits = paying, depth = depth, floorLevel = opts.floorLevel,
            houseMaterial = opts.houseMaterial, combat = combat, rescue = rescue, player = player,
            run = player and player.descentRun or nil,
        })
        if spoils and opts.objectiveReward then spoils.awarded = opts.objectiveReward() end
        if spoils and rescue.delvers and #rescue.delvers > 0 then spoils.delvers = rescue.delvers end
        if player and combat.xpByChar then
            local fielded = {}
            for _, u in ipairs(combat.units or {}) do
                if u.char and Combat.isPlayerControlled(u) and not u.summoned then fielded[#fielded + 1] = u.char end
            end
            Experience.payBench(player.roster, fielded, combat.xpByChar)
        end
        sim.run.goldWon = sim.run.goldWon + ((spoils and spoils.gold) or 0)
        report(fmt(", +%dg (purse %d)", (spoils and spoils.gold) or 0, (player and player.gold) or 0))
        if opts.onWin then opts.onWin(spoils) end
        return
    end

    -- battle.lua's lose(); an undecided fight (nil at the turn cap) is read as a rout.
    if result == nil then rec.result = "stall"; sim.run.stalls = sim.run.stalls + 1 end
    if result == "crash" then
        sim.run.crashes = sim.run.crashes + 1
        local where = crash:match("^[^\n]*") or crash
        sim.run.notes[#sim.run.notes + 1] = "engine error in " .. tostring(rec.id) .. ": " .. where
        sim.crashTraces[#sim.crashTraces + 1] = crash
    end
    SimBattle.fallen = Combat.fallenParty(combat)
    for _, char in ipairs(Combat.spentParty(combat)) do SimBattle.fallen[#SimBattle.fallen + 1] = char end
    SimBattle.routed = result == nil or result == "crash" or not Combat.eliminated(combat, "party")
    if not SimBattle.routed then sim.run.wipedBy = fmt("wiped by %s on floor %d", tostring(rec.id), depth) end
    report(SimBattle.routed and " (routed)" or " (wiped)")
    releaseParty(combat)
    if opts.onLoss then opts.onLoss() end
end

function SimBattle.update() end
function SimBattle.draw() end

-- ---------------------------------------------------------------------------
-- The company and the policy's reads of it
-- ---------------------------------------------------------------------------

local function freshSave(seed)
    local prologue = require("states.prologue")
    local player = Player.new()
    player.seed = seed
    prologue.skip(player)
    local avatar
    for _, c in ipairs(player.roster) do if c.id == Class.AVATAR_ID then avatar = c end end
    local ok, gift = Class.unlock(player, avatar, M.AVATAR_CLASS)
    assert(ok, "the free first pick refused: " .. tostring(gift))
    if gift then
        for i, item in ipairs(player.stash or {}) do
            if item.id == gift then
                if Character.addItem(avatar, Item.instantiate(gift)) then table.remove(player.stash, i) end
                break
            end
        end
    end
    local joins = require("models.conversation").pendingJoins
    if joins then for i = #joins, 1, -1 do joins[i] = nil end end
    Player.restore(player)
    return player
end

local function party()
    return Descent.party(sim.player.descentRun, sim.player)
end

local function companyHealth()
    local cur, max = 0, 0
    for _, c in ipairs(party()) do
        local hp = c.stats and c.stats.health
        if type(hp) == "table" then
            max = max + (hp.max or 0)
            cur = cur + math.max(0, hp.current or 0)
        end
    end
    return max > 0 and cur / max or 0
end

local function countHeld(char, id)
    local n = 0
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then n = n + (it.quantity or 1) end
    end
    return n
end

-- Put `n` of `id` in somebody's hand (a fight can only reach a body's own grid -- the pack is not on
-- the board), buying what is missing at shelf price while the purse allows. Spillover goes to the pack.
local function kitUp(id, want)
    local player = sim.player
    local price = (Item.defs[id] or {}).price or 0
    local have = 0
    for _, c in ipairs(party()) do have = have + countHeld(c, id) end
    local bought = 0
    while have < want and (player.gold or 0) >= price do
        Player.spendGold(player, price)
        local item = Item.instantiate(id)
        item.quantity = 1
        local placed = false
        for _, c in ipairs(party()) do
            if Character.addItem(c, item) then placed = true; break end
        end
        if not placed then Player.addToPack(player, item) end
        have, bought = have + 1, bought + 1
    end
    return bought
end

-- The Ward (ui/panels/ward.lua): pay for each injury while the purse allows, else rest the body off.
local function ward()
    local player = sim.player
    local paid, rested = 0, 0
    for _, entry in ipairs(Injury.injured(player)) do
        local id = entry.char.id
        if Injury.resting(player, id) <= 0 then
            while Injury.count(player, id) > 0 and (player.gold or 0) >= Injury.TREAT_COST do
                if not Injury.treat(player, id) then break end
                paid = paid + 1
            end
            if Injury.count(player, id) > 0 and Injury.rest(player, id) > 0 then rested = rested + 1 end
        end
    end
    Player.restore(player)
    return paid, rested
end

-- ---------------------------------------------------------------------------
-- Answering the screen
-- ---------------------------------------------------------------------------

local function call(fn, ...) if type(fn) == "function" then fn(...) return true end return false end

local function optionLabeled(options, pattern)
    for _, o in ipairs(options or {}) do
        if tostring(o.label or ""):find(pattern) then return o end
    end
    return nil
end

local function note(text)
    if sim.verbose then print("        " .. text) end
end

local function answer(panel)
    local kind, o = panel.simKind, panel.opts
    if kind == "choice" then
        local opts = o.options or {}
        local pick
        if optionLabeled(opts, "^Auto%-resolve") then
            pick = optionLabeled(opts, "^Auto%-resolve")
            sim.run.walkOffs = sim.run.walkOffs + 1
            note("walk-off: auto-resolve")
        elseif optionLabeled(opts, "^Pay$") then
            pick = optionLabeled(opts, "^Pay$")
        elseif o.title == "The Stair Down" then
            pick = sim.leaving and optionLabeled(opts, "^Not yet") or optionLabeled(opts, "^Go down")
        elseif optionLabeled(opts, "^Climb out") then
            pick = sim.leaving and optionLabeled(opts, "^Climb out") or optionLabeled(opts, "^Stay down")
            if sim.leaving then sim.climbing = true end
        elseif optionLabeled(opts, "^Step around") then
            pick = optionLabeled(opts, "^Step around")
        elseif optionLabeled(opts, "^Not now") then
            pick = optionLabeled(opts, "^Not now")
        elseif optionLabeled(opts, "^Gamble") or optionLabeled(opts, "^Trade") then
            pick = nil
        elseif optionLabeled(opts, "^Cut your way out") then
            pick = optionLabeled(opts, "^Stay down")
        else
            pick = opts[1]
            sim.crossroads = (sim.crossroads or 0) + 1
            note("choice '" .. tostring(o.title) .. "': took '" .. tostring(pick and pick.label) .. "'")
        end
        if pick then return call(pick.cb) end
        return call(o.onClose)
    elseif kind == "rest_choice" then
        return call(o.onHeal) or call(o.onBind) or call(o.onClose)
    elseif kind == "rest" then
        return call(o.onDone)
    elseif kind == "loot_reveal" then
        if o.onOpen then
            sim.run.mimics = sim.run.mimics + 1
            return call(o.onOpen)
        end
        return call(o.onCollect) or call(o.onCancel)
    elseif kind == "relic_offer" then
        if o.offer and o.offer[1] then
            note("relic: took " .. tostring(o.offer[1].id))
            return call(o.onTake, o.offer[1])
        end
        return call(o.onLeave)
    elseif kind == "relic_reveal" then
        if o.priceLabel then return call(o.onLeave) end
        note("relic: took " .. tostring(o.relic and o.relic.id))
        return call(o.onTake)
    elseif kind == "battle_summary" then
        local a = o.actions and o.actions[1]
        local r = a and call(a.onSelect)
        if M.TRACE then note("walk-off settled, xp " .. xpLine()) end
        return r
    elseif kind == "encounter" then
        return call(o.onResolve) or call(o.onClose)
    end
    local DECLINED = { tutorial_note = true, merchant = true, anvil = true, maw = true }
    if not DECLINED[kind] then sim.unknown[kind] = (sim.unknown[kind] or 0) + 1 end
    return call(o.onClose) or call(o.onLeave) or call(o.onCancel) or call(o.onDone) or call(o.onCollect)
end

local function settle()
    local game = require("states.game")
    for _ = 1, 40 do
        if sim.ended then return end
        local p = game.activePanel
        if not p then return end
        if type(p) ~= "table" or not p.simKind then game.activePanel = nil; return end
        answer(p)
        if game.activePanel == p then game.activePanel = nil end
    end
    game.activePanel = nil
end

-- ---------------------------------------------------------------------------
-- Walking a floor
-- ---------------------------------------------------------------------------

local SKIP = { shrine = true, weeping_stone = true, merchant = true, anvil = true, maw = true, drop = true,
    dark = true, spinner = true, translation = true, ascent = true, stair = true, road = true }

local function key(x, y) return y * 10000 + x end

-- Shortest walkable path from (sx,sy) to (tx,ty); `avoid` keeps it off unvisited stops when it can.
local function path(grid, keys, sx, sy, tx, ty, avoid)
    local prev = { [key(sx, sy)] = false }
    local q, head = { { sx, sy } }, 1
    while q[head] do
        local x, y = q[head][1], q[head][2]
        head = head + 1
        if x == tx and y == ty then break end
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = x + d[1], y + d[2]
            local k = key(nx, ny)
            if prev[k] == nil and grid:isWalkable(nx, ny, keys) then
                local c = grid:get(nx, ny)
                local blocked = avoid and not (nx == tx and ny == ty) and c and c.encounter and not c.cleared
                if not blocked then
                    prev[k] = { x, y }
                    q[#q + 1] = { nx, ny }
                end
            end
        end
    end
    if prev[key(tx, ty)] == nil then return nil end
    local steps, cx, cy = {}, tx, ty
    while not (cx == sx and cy == sy) do
        local p = prev[key(cx, cy)]
        table.insert(steps, 1, { cx - p[1], cy - p[2] })
        cx, cy = p[1], p[2]
    end
    return steps
end

local function routeTo(grid, map, tx, ty)
    return path(grid, map.keysHeld, map.px, map.py, tx, ty, true)
        or path(grid, map.keysHeld, map.px, map.py, tx, ty, false)
end

local function wanted(grid)
    local out = {}
    local stair = grid.objective and grid:get(grid.objective.x, grid.objective.y)
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            local e = c.encounter
            local want = false
            if e and not c.cleared and c ~= stair and not SKIP[e.kind] then want = true end
            if c.cache and not c.picked then want = true end
            if c.key and not c.picked then want = true end
            if want and not sim.skip[c] then out[#out + 1] = c end
        end
    end
    return out, stair
end

local function findKind(grid, kind)
    for y = 1, grid.rows do
        for x = 1, grid.cols do
            local c = grid.cells[y][x]
            if c.encounter and c.encounter.kind == kind then return c end
        end
    end
    return nil
end

-- One step; settles whatever the step opened. Returns false when the run has ended or the floor changed.
local function stepOnce(dx, dy)
    local game = require("states.game")
    local grid = game.grid
    sim.floorSteps = sim.floorSteps + 1
    game.map:step(dx, dy)
    settle()
    if sim.ended or game.grid ~= grid then return false end
    -- THE USE PANEL (states/game.lua's openConsumables): a body left at nothing drinks a draught on the
    -- road rather than walking into the next fight already down.
    if game.descent then
        for _, char in ipairs(party()) do
            local hp = char.stats and char.stats.health
            if type(hp) == "table" and (hp.current or 0) <= 0 then
                for _, entry in ipairs(Player.partyRestoratives(sim.player, { party = party(), stash = false })) do
                    if Combat.restorativeStat(entry.item) == "health" then
                        Player.consumeRestorative(sim.player, entry, char)
                        sim.run.roadDraughts = sim.run.roadDraughts + 1
                        note(fmt("road draught for %s: health %s", tostring(char.name), tostring(hp.current)))
                        break
                    end
                end
            end
        end
    end
    if not sim.leaving and game.descent then
        if companyHealth() < M.POLICY.climbBelow then
            sim.leaving = true
            sim.run.reason = fmt("health %.0f%% on floor %d", companyHealth() * 100, Descent.depth(game.descent))
            note("leaving: " .. sim.run.reason)
        end
    end
    return true
end

-- Walk to (tx,ty) along the current best path, re-planning as the board changes.
local function walkTo(tx, ty)
    local game = require("states.game")
    local grid = game.grid
    local leavingAtStart = sim.leaving
    while not sim.ended and game.grid == grid do
        if sim.leaving ~= leavingAtStart then return "replan" end
        if game.map.px == tx and game.map.py == ty then return "here" end
        if sim.floorSteps > M.POLICY.maxSteps then return "stuck" end
        local steps = routeTo(grid, game.map, tx, ty)
        if not steps or #steps == 0 then return "unreachable" end
        local s = steps[1]
        local bx, by = game.map.px, game.map.py
        if not stepOnce(s[1], s[2]) then return "moved" end
        -- Stepped onto the target and it fired (or a fight retreated us): the cell is done with.
        if game.map.px == bx and game.map.py == by then
            local c = grid:get(bx + s[1], by + s[2])
            if c and c.x == tx and c.y == ty then return "here" end
        end
    end
    return "moved"
end

-- The way out: walk to the floor's ascent and take "Climb out". If the floor has none (or it cannot be
-- reached), the climb-out branch's bookkeeping is the game's own: the cell's encounter is opened in place.
local function climbOut()
    local game = require("states.game")
    local grid = game.grid
    local up = findKind(grid, "ascent")
    if not up then
        sim.run.notes[#sim.run.notes + 1] = "no ascent cell; opened in place"
        up = grid:startCell()
        up.encounter = { kind = "ascent", name = "The Way Up" }
        up.cleared = nil
        game:openEncounter(up)
        settle()
        return
    end
    local r = walkTo(up.x, up.y)
    if sim.ended or game.grid ~= grid then return end
    if r ~= "here" or not sim.climbing then
        -- Standing on it already (arrival tile) or the walk was cut short: ask the cell directly.
        up.cleared = nil
        game:openEncounter(up)
        settle()
    end
end

local function walkFloor()
    local game = require("states.game")
    local grid = game.grid
    local floor = Descent.depth(game.descent)
    sim.floorSteps = 0
    sim.run.floor = math.max(sim.run.floor, floor)
    note(fmt("floor %d (%s) -- health %.0f%%, gold %d", floor, tostring(game.quest and game.quest.sin),
        companyHealth() * 100, sim.player.gold or 0))
    settle()
    while not sim.ended and game.grid == grid do
        if sim.leaving then climbOut(); return end
        local targets, stair = wanted(grid)
        local best, bestN
        for _, c in ipairs(targets) do
            local p = routeTo(grid, game.map, c.x, c.y)
            if p and (not bestN or #p < bestN) then best, bestN = c, #p end
        end
        local target = best or stair
        if not target then sim.run.notes[#sim.run.notes + 1] = "no stair"; sim.leaving = true; climbOut(); return end
        if target == stair and stair.encounter and stair.encounter.kind == "stair" then
            -- The stair is open: the landing's own check, then down (or out).
            local capped = sim.maxFloor and floor >= sim.maxFloor
            if not sim.leaving and (capped or companyHealth() < M.POLICY.afterStairBelow) then
                sim.leaving = true
                sim.run.reason = capped and fmt("floor cap %d", sim.maxFloor)
                    or fmt("health %.0f%% at the stair of floor %d", companyHealth() * 100, floor)
                note("leaving: " .. sim.run.reason)
                climbOut()
                return
            end
        end
        local r = walkTo(target.x, target.y)
        if sim.ended or game.grid ~= grid then return end
        if r == "here" and target ~= stair then
            -- Visited and still standing (a rout, a chest with no room, a posting turned down): one more
            -- try, then it is left where it is.
            sim.tries[target] = (sim.tries[target] or 0) + 1
            if sim.tries[target] >= 2 then sim.skip[target] = true end
        end
        if r == "here" and target == stair then
            -- Retreated off it by the fight, or a barred stair: ask it again from beside it.
            if stair.encounter and not stair.cleared then
                game:openEncounter(stair)
                settle()
                if sim.ended or game.grid ~= grid then return end
            end
            if stair.encounter and stair.encounter.kind ~= "stair" and not stair.cleared then
                sim.run.notes[#sim.run.notes + 1] = fmt("floor %d stair would not open", floor)
                sim.leaving = true
            end
        elseif r == "unreachable" then
            if target == stair then
                sim.run.notes[#sim.run.notes + 1] = fmt("floor %d stair unreachable", floor)
                sim.leaving = true
            else
                sim.skip[target] = true -- behind a gate with no key: let it be
            end
        elseif r == "stuck" then
            sim.run.notes[#sim.run.notes + 1] = fmt("floor %d step cap", floor)
            sim.leaving = true
        end
    end
end

-- ---------------------------------------------------------------------------
-- One save, N runs
-- ---------------------------------------------------------------------------

local function shortName(char)
    return (tostring(char.name or char.id):gsub("^character_", "")):sub(1, 2)
end

local function companySnapshot(player)
    local levels, classes, injuries, resting = {}, {}, {}, {}
    for _, c in ipairs(player.roster or {}) do
        local n = shortName(c)
        levels[#levels + 1] = n .. (c.level or 1)
        local cls = Class.declaredOf(c)
        classes[#classes + 1] = n .. ":" .. (cls and (tostring(cls):sub(1, 4) .. Class.classLevel(c, cls)) or "-")
        local k = Injury.count(player, c.id)
        if k > 0 then injuries[#injuries + 1] = n .. k end
        local left = Injury.resting(player, c.id)
        if left > 0 then resting[#resting + 1] = n .. "(" .. left .. ")" end
    end
    return { levels = table.concat(levels, " "), classes = table.concat(classes, " "),
        injuries = #injuries > 0 and table.concat(injuries, " ") or "-",
        injuryCount = #injuries,
        resting = #resting > 0 and table.concat(resting, " ") or "-", roster = #(player.roster or {}) }
end

local function generalsFelled(player)
    local n = 0
    for _, v in pairs(player.standing or {}) do n = n + (v or 0) end
    return n
end

local function playRun(index)
    local State = require("states")
    local game = require("states.game")
    local Gate = require("models.gate")
    local player = sim.player

    sim.run = { index = index, fights = {}, smokes = 0, walkOffs = 0, mimics = 0, stalls = 0, goldWon = 0,
        roadDraughts = 0, crashes = 0,
        floor = 0, notes = {}, relics = {}, cleared = 0, generals = 0, gold = newLedger() }
    sim.ended, sim.leaving, sim.climbing = nil, false, false
    sim.skip, sim.tries = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })

    -- THE CITY between trips: the hub's restore, then the Ward, then the Gate's kit.
    if index > 1 then
        Player.restore(player)
        local before = player.gold or 0
        sim.run.wardPaid, sim.run.wardRested = ward()
        sim.run.gold.ward = before - (player.gold or 0)
    end
    local run = Descent.new(player)
    player.descentRun = run
    sim.run.party = #Descent.party(run, player)
    Gate.payPurse(player, Descent.OPENING_GOLD)
    sim.run.boughtSmokes = kitUp(M.POLICY.smoke, M.POLICY.packSmokes)
    sim.run.boughtDraughts = kitUp(M.POLICY.draught, M.POLICY.packDraughts)
    sim.run.goldStart = player.gold or 0
    sim.run.trips = player.tripsCounted or 0
    note(fmt("run %d: party %d, bought %d smoke + %d draught, purse %d, trips %d", index, sim.run.party,
        sim.run.boughtSmokes, sim.run.boughtDraughts, sim.run.goldStart, sim.run.trips))

    -- states/gate.lua's descend()
    Descent.markGateCoached(player)
    run.entry = nil
    Player.active = player
    State.switch(game, Descent.floorQuest(run, player), nil, player)

    local guard = 0
    while not sim.ended do
        guard = guard + 1
        if guard > 60 or not game.descent then
            sim.run.notes[#sim.run.notes + 1] = "walker lost the floor"
            break
        end
        walkFloor()
    end
    sim.run.ending = sim.ended or "?"
    sim.run.goldLost = player.pendingGoldLost or 0
    player.pendingGoldLost = nil
    -- states/hub.lua's enter: the company is topped back up to what its injuries leave it.
    Player.restore(player)
    player.pendingRout, player.pendingDead = nil, nil
    player.activeRun = nil
    sim.run.goldEnd = player.gold or 0
    sim.run.company = companySnapshot(player)
    sim.run.generalsTotal = generalsFelled(player)
    local wins = 0
    for _, f in ipairs(sim.run.fights) do
        if f.result == "win" then wins = wins + 1 end
    end
    sim.run.battles, sim.run.wins = #sim.run.fights, wins
    return sim.run
end

-- One fresh save played for `runs` descents. `opts.maxFloor` (the spec's knob) climbs out at that
-- floor's opened stair whatever the health, so a short check still walks the whole loop.
function M.simulateSave(saveSeed, runs, verbose, opts)
    local State = require("states")
    local Arena = require("models.arena")
    local Sound = require("models.sound")
    local Conversation = require("models.conversation")

    sim = { saveSeed = saveSeed, fightIndex = 0, verbose = verbose, unknown = {}, runs = {},
        maxFloor = opts and opts.maxFloor or nil, crashTraces = {} }
    math.randomseed(saveSeed)
    if love.math and love.math.setRandomSeed then love.math.setRandomSeed(saveSeed) end

    local ok, err = xpcall(function()
        if not (love.window and love.window.isOpen and love.window.isOpen()) and love.graphics then
            swap(love.graphics, "newFont", function() return fakeFont() end)
        end
        swap(Player, "save", function() end)
        swap(Player, "active", Player.active)
        swap(Combat, "FORCE_HIT", false)
        swap(Sound, "play", function() end)
        swap(Sound, "music", function() end)
        swap(Conversation, "play", function(_, onDone)
            if type(onDone) == "function" then onDone("accept") end
        end)
        swap(Arena, "randomSeed", function()
            sim.fightIndex = sim.fightIndex + 1
            return Seed.mix(saveSeed, 7777, sim.fightIndex)
        end)
        local endTrip = Relic.endTrip
        swap(Relic, "endTrip", function(run, player)
            if sim.run and run then
                local names = {}
                for _, e in ipairs(Relic.held(run.relicState)) do
                    names[#names + 1] = (tostring(e.id):gsub("^relic_", "")) .. (e.count > 1 and ("x" .. e.count) or "")
                end
                sim.run.relics = names
                sim.run.cleared = run.cleared or 0
                local g = 0
                for _, v in pairs(run.standing or {}) do g = g + v end
                sim.run.generals = g
            end
            return endTrip(run, player)
        end)
        stubPanels()
        installGoldLedger()
        swap(package.loaded, "states.battle", SimBattle)
        local game = require("states.game")
        local hub, credits = require("states.hub"), require("states.credits")
        local realSwitch = State.switch
        swap(State, "current", State.current)
        swap(State, "switch", function(state, ...)
            if state == game then return realSwitch(state, ...) end
            State.current = state
            if state == hub then
                sim.ended = sim.player.pendingRout and "wipe" or (sim.climbing and "climb" or "home")
            elseif state == credits then
                sim.ended = "crown"
            else
                sim.ended = "other"
            end
        end)

        sim.player = freshSave(saveSeed)
        sim.start = companySnapshot(sim.player)
        for r = 1, runs do
            sim.runs[r] = playRun(r)
        end
    end, debug.traceback)
    restoreAll()
    -- Nothing the sim did may leak into whoever runs next (the suite): the recruit queue and the
    -- overworld's open panel/fight are module state.
    local joins = Conversation.pendingJoins
    if joins then for i = #joins, 1, -1 do joins[i] = nil end end
    local game = package.loaded["states.game"]
    if game then game.activePanel, game.battle = nil, nil end
    if not ok then error(err, 0) end
    return { seed = saveSeed, runs = sim.runs, unknown = sim.unknown, start = sim.start,
        crashTraces = sim.crashTraces,
        crossroads = sim.crossroads or 0 }
end

-- ---------------------------------------------------------------------------
-- The report
-- ---------------------------------------------------------------------------

local function median(list)
    if #list == 0 then return nil end
    local t = {}
    for i, v in ipairs(list) do t[i] = v end
    table.sort(t)
    local m = math.floor((#t + 1) / 2)
    if #t % 2 == 1 then return t[m] end
    return (t[m] + t[m + 1]) / 2
end

function M.policyLines()
    local P = M.POLICY
    return {
        fmt("  climb out when the expedition's health < %d%%, or < %d%% standing on an opened stair",
            P.climbBelow * 100, P.afterStairBelow * 100),
        fmt("  Smoke when %d+ of the company are down and the enemy side holds > %d%% of its health (not on a stair)",
            P.smokeDown, P.smokeEnemyAbove * 100),
        fmt("  at the Gate: top up to %d Smoke and %d %s in hand, bought at shelf price if affordable",
            P.packSmokes, P.packDraughts, P.draught),
        "  Ward between runs: pay 40g per injury while affordable, else rest the body (the avatar cannot rest)",
        "  route: greedy tour of every fight/chest/cache/key/camp/reliquary/event/errand/crossroads, stair last",
        "  walk-offs: Auto-resolve when offered; camps: heal if anyone is short, else bind an injury",
        "  relics: first in every slate, every elite drop; altars, weeping stones, merchants, anvils declined",
        "  on the road: a body left at 0 health drinks a carried healing draught (the Use panel); no other road use",
        "  crossroads: first option; stray delvers: declined; tolls: paid; holes: stepped around",
        fmt("  avatar's free class: %s; fights over %d unit-turns are called a rout", M.AVATAR_CLASS, P.maxTurns),
    }
end

-- THE GOLD BREAKDOWN: every coin the runs earned, by where it came from -- across all saves, per run,
-- and per floor band. Report only: it names the faucets, it does not judge them.
function M.goldTotals(results)
    local out = { bySource = {}, byBand = {}, byRun = {}, total = 0, runs = 0, spent = 0, spentBy = {},
        topUp = 0, ward = 0, lostOnWipe = 0 }
    local function bandOf(f)
        for i, b in ipairs(M.GOLD_BANDS) do if f >= b[1] and f <= b[2] then return i end end
        return 0
    end
    for _, res in ipairs(results) do
        for r, run in ipairs(res.runs) do
            local led = run.gold
            out.runs = out.runs + 1
            out.total = out.total + led.total
            out.spent, out.topUp, out.ward = out.spent + led.spent, out.topUp + led.topUp, out.ward + (led.ward or 0)
            out.lostOnWipe = out.lostOnWipe + (run.goldLost or 0)
            out.byRun[r] = (out.byRun[r] or 0) + led.total
            for k, v in pairs(led.bySource) do out.bySource[k] = (out.bySource[k] or 0) + v end
            for k, v in pairs(led.spentBy) do out.spentBy[k] = (out.spentBy[k] or 0) + v end
            for f, t in pairs(led.byFloor) do
                local b = bandOf(f)
                out.byBand[b] = out.byBand[b] or {}
                for k, v in pairs(t) do out.byBand[b][k] = (out.byBand[b][k] or 0) + v end
            end
        end
    end
    return out
end

function M.printGold(results, runs, saves)
    local g = M.goldTotals(results)
    if g.runs == 0 then return end
    local labels = {}
    for k in pairs(g.bySource) do labels[#labels + 1] = k end
    table.sort(labels, function(a, b) return g.bySource[a] > g.bySource[b] end)
    print("")
    print(fmt("GOLD BREAKDOWN -- %d run(s); earned %d in all, %.0f per run (the Gate's top-up of %d not counted)",
        g.runs, g.total, g.total / g.runs, g.topUp))
    local bandHead = {}
    for i, b in ipairs(M.GOLD_BANDS) do bandHead[i] = fmt("%8s", fmt("F%d-%d", b[1], b[2])) end
    print(fmt("  %-40s %8s %6s %7s  %s", "source", "total", "share", "per run", table.concat(bandHead, " ")))
    for _, k in ipairs(labels) do
        local cells = {}
        for i = 1, #M.GOLD_BANDS do
            local t = g.byBand[i]
            cells[i] = fmt("%8d", (t and t[k]) or 0)
        end
        print(fmt("  %-40s %8d %5.1f%% %7.0f  %s", k:sub(1, 40), g.bySource[k], 100 * g.bySource[k] / math.max(1, g.total),
            g.bySource[k] / g.runs, table.concat(cells, " ")))
    end
    local totals = {}
    for i = 1, #M.GOLD_BANDS do
        local n = 0
        for _, v in pairs(g.byBand[i] or {}) do n = n + v end
        totals[i] = fmt("%8d", n)
    end
    print(fmt("  %-40s %8d %6s %7.0f  %s", "ALL", g.total, "", g.total / g.runs, table.concat(totals, " ")))
    local perRun = {}
    for r = 1, runs do perRun[#perRun + 1] = fmt("run %d: %.0f", r, (g.byRun[r] or 0) / math.max(1, saves)) end
    print("  mean earned by run index: " .. table.concat(perRun, ", "))
    local sinks = {}
    for k, v in pairs(g.spentBy) do sinks[#sinks + 1] = { k, v } end
    table.sort(sinks, function(a, b) return a[2] > b[2] end)
    local sl = {}
    for _, e in ipairs(sinks) do sl[#sl + 1] = fmt("%s %d", e[1], e[2]) end
    print(fmt("  spent through Player.spendGold: %d (%s); at the Ward: %d; lost on wipes: %d",
        g.spent, #sl > 0 and table.concat(sl, ", ") or "-", g.ward, g.lostOnWipe))
end

function M.report(args)
    args = args or {}
    local runs, saves, seed, verbose = 3, 5, M.SEED_BASE, false
    for _, a in ipairs(args) do
        a = tostring(a)
        local r = a:match("^runs=(%d+)$"); if r then runs = tonumber(r) end
        local s = a:match("^saves=(%d+)$"); if s then saves = tonumber(s) end
        local sd = a:match("^seed=(%d+)$"); if sd then seed = tonumber(sd) end
        if a == "verbose" then verbose = true end
        if a == "trace" then verbose = true; M.TRACE = true end
    end
    local t0 = os.clock()
    print(fmt("RUN SIM -- %d save(s) x %d run(s), seed %d, dice live", saves, runs, seed))
    print("  (affixes/dressing are whatever this tree's data/affixes says)")
    print("POLICY")
    for _, l in ipairs(M.policyLines()) do print(l) end
    print("")

    local results = {}
    for s = 1, saves do
        local saveSeed = Seed.mix(seed, s)
        if verbose then print(fmt("save %d (seed %d)", s, saveSeed)) end
        local res = M.simulateSave(saveSeed, runs, verbose)
        results[s] = res
        print(fmt("save %d  seed %-7d start: %s", s, saveSeed, res.start.levels))
        print(fmt("  %-3s %-6s %5s %4s %7s %5s %5s %-28s %6s %5s  %s", "run", "end", "floor", "clr", "fights",
            "won", "smoke", "relics", "gold", "party", "why"))
        for r, run in ipairs(res.runs) do
            local relics = #run.relics > 0 and table.concat(run.relics, ",") or "-"
            if #relics > 28 then relics = relics:sub(1, 26) .. ".." end
            print(fmt("  %-3d %-6s %5d %4d %4d+%-2d %5d %5d %-28s %+6d %5d  %s", r, run.ending, run.floor,
                run.cleared, run.battles, run.walkOffs, run.wins, run.smokes, relics,
                run.goldEnd - run.goldStart, run.party, run.wipedBy or run.reason or ""))
            print(fmt("      levels %s | class %s | injured %s | resting %s | gold %d%s%s",
                run.company.levels, run.company.classes, run.company.injuries, run.company.resting, run.goldEnd,
                run.wardPaid and fmt(" | ward before: %d paid, %d rested", run.wardPaid, run.wardRested) or "",
                (run.stalls > 0 and fmt(" | %d fight(s) undecided", run.stalls) or "")
                .. (run.roadDraughts > 0 and fmt(" | %d road draught(s)", run.roadDraughts) or "")
                .. (run.mimics > 0 and fmt(" | %d mimic(s)", run.mimics) or "")
                .. (run.crashes > 0 and fmt(" | %d ENGINE ERROR(S)", run.crashes) or "")))
            if #run.notes > 0 then print("      notes: " .. table.concat(run.notes, "; ")) end
        end
        local unk = {}
        for k, v in pairs(res.unknown) do unk[#unk + 1] = k .. " x" .. v end
        table.sort(unk)
        if #unk > 0 then print("  panels closed unanswered: " .. table.concat(unk, ", ")) end
    end

    print("")
    print("ACROSS SAVES")
    print(fmt("  %-4s %8s %8s %8s %12s %10s", "run", "wipes", "climbs", "crowns", "median floor", "mean fights"))
    for r = 1, runs do
        local wipes, climbs, crowns, floors, fights = 0, 0, 0, {}, 0
        for _, res in ipairs(results) do
            local run = res.runs[r]
            if run.ending == "wipe" then wipes = wipes + 1 end
            if run.ending == "climb" then climbs = climbs + 1 end
            if run.ending == "crown" then crowns = crowns + 1 end
            floors[#floors + 1] = run.floor
            fights = fights + run.battles + run.walkOffs
        end
        print(fmt("  %-4d %3d/%-4d %3d/%-4d %3d/%-4d %12s %10.1f", r, wipes, saves, climbs, saves, crowns, saves,
            tostring(median(floors)), fights / saves))
    end
    local firsts, line = {}, {}
    for _, res in ipairs(results) do
        local first
        for r, run in ipairs(res.runs) do
            if run.generalsTotal > 0 then first = r; break end
        end
        line[#line + 1] = first and tostring(first) or "never"
        if first then firsts[#firsts + 1] = first end
    end
    print(fmt("  runs until the first general falls, per save: %s  (fell in %d of %d saves%s)",
        table.concat(line, " "), #firsts, saves,
        #firsts > 0 and fmt(", median run %s", tostring(median(firsts))) or ""))
    -- Every distinct engine error, once, with the frames that place it.
    local seen, any = {}, false
    for _, res in ipairs(results) do
        for _, trace in ipairs(res.crashTraces or {}) do
            local head = trace:match("^[^\n]*") or trace
            if not seen[head] then
                seen[head] = true
                if not any then print(""); print("ENGINE ERRORS (a fight threw; played as a rout)"); any = true end
                local lines, n = {}, 0
                for line in trace:gmatch("[^\n]+") do
                    n = n + 1
                    if n <= 7 then lines[#lines + 1] = "    " .. line end
                end
                print(table.concat(lines, "\n"))
            end
        end
    end
    M.printGold(results, runs, saves)
    print(fmt("  took %.1fs", os.clock() - t0))
    return results
end

-- A headless LÖVE error looks like a hang (no window to draw the blue screen on), so the report runs
-- under a traceback and a failure is printed rather than raised.
function M.run(args)
    local ok, res = xpcall(function() return M.report(args) end, debug.traceback)
    if not ok then print("RUN SIM FAILED: " .. tostring(res)) return nil end
    return res
end

return M
