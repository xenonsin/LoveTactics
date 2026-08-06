-- Balance ledger: run with
--
--     & "E:\LOVE\lovec.exe" . balance-report [full | sim [n]]
--
-- Measures the game's two number scales against each other. Combat has one damage formula and it is
-- purely subtractive, so a weapon's power and a body's armour are quantities in the SAME unit -- but
-- they were authored on different scales by different passes, and nothing in the repo could say so.
-- The symptom was a level-1 party dealing the floor of 1 to the second line's first armoured body.
--
-- This walks every quest in the order a player meets them, asks models/balance.lua what the reference
-- loadout throws at that point and what each body it fields subtracts from it, and reports the
-- exchange in both directions. Everything it prints comes out of Combat.mitigatedDamage itself
-- (Balance measures THROUGH the formula rather than reimplementing it), so the report cannot disagree
-- with the game.
--
-- WORST FIRST. The three failure sections lead, because the point of the tool is to be read at the
-- top and acted on, not scrolled:
--
--     UNHITTABLE   the reference budget floors against this body -- you cannot hurt it
--     DOMINATES    this body beats the reference loadout on attack AND armour AND health
--     HARMLESS     the mirror -- this body floors against the reference loadout and is no threat
--
-- WHAT `sim` CANNOT SEE. EncounterBattle.eligible refuses any fight carrying an `objective` or
-- `allies`, which is most quest objectives -- including the one that prompted this tool. So the
-- simulator covers trail encounters and nothing else, and it is deliberately NOT the headline: the
-- static sections above are what cover the fights that actually go wrong. Read `sim` as a check that
-- the ordinary road is survivable, never as the verdict.
--
-- Read-only. It touches no files and mutates no save; every player it walks is a throwaway table.

local Balance = require("models.balance")
local Character = require("models.character")
local Quest = require("models.quest")
local Item = require("models.item")
local Vendor = require("models.vendor")
local Discipline = require("models.discipline")
local Forge = require("models.forge")
local Growth = require("models.growth")

local M = {}

-- How many quests deep the reference curve is printed without `full`. Enough to cover the on-ramp,
-- where every reported failure so far has lived.
local BRIEF_PRESTIGE = 12

local function questCount()
    local n = 0
    for _ in pairs(Quest.defs) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------
-- The walks. Pure data, so tests/balance_spec.lua can assert on them rather than on printed text.
-- ---------------------------------------------------------------------------

-- The reference loadout at every prestige the campaign reaches: what it throws, what it wears, and
-- how far up the forge ladder it is allowed to be. The denominator every other section is read in.
function M.walkReference()
    local rows = {}
    local total = questCount()
    for prestige = 1, total do
        local budget, parts = Balance.attackBudget(prestige)
        local ref = Balance.unitFor(Balance.refChar(prestige))
        rows[#rows + 1] = {
            prestige = prestige,
            level = Growth.levelForPrestige(prestige),
            budget = budget,
            parts = parts,
            ceiling = Balance.forgeCeiling(Balance.REFERENCE.weapon, prestige),
            mitigation = Balance.mitigation(ref, Balance.PROBES.slash.tags).total,
            hp = Balance.healthOf(ref.char),
        }
    end
    return rows
end

-- Every body the campaign fields, measured against all four probes at the EARLIEST standing it is met
-- at -- one row per blueprint, matching tests/balance_spec.lua's sweep so the report and the guard
-- never disagree about which appearance counts.
--
-- The introduction is the binding case: it is where the player has least to answer with, and fixing
-- it fixes every later appearance. Later appearances read easier on purpose -- Growth.ENEMY_LEVEL_LAG
-- exists so the company pulls ahead of common stock -- so reporting them would be reporting the
-- system working.
--
-- `physical` is the probe the player would actually pick from a melee company; `best` includes magic
-- and is diagnostic. A body is only unhittable if EVERY tool fails against it, so reporting the worst
-- probe instead would flag every specialist armour in the game.
function M.walkBodies()
    local byId = {}
    for _, questId in ipairs(Balance.questOrder()) do
        local def = Quest.defs[questId]
        local prestige = Balance.prestigeFor(questId)
        local sponsorDone = Balance.sponsorDoneFor(questId)
        for _, body in ipairs(Balance.bodiesFor(questId)) do
            local cur = byId[body.id]
            if not Balance.isPlaceholder(body.id) and (not cur or prestige < cur.prestige) then
                local row = Balance.measure(prestige, body.id, body.role, { sponsorDone = sponsorDone })
                row.source = body.source
                row.quest = questId
                row.difficulty = def.difficulty
                byId[body.id] = row
            end
        end
    end

    local rows = {}
    for _, row in pairs(byId) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b)
        if a.prestige ~= b.prestige then return a.prestige < b.prestige end
        return a.id < b.id
    end)
    return rows
end

-- Per quest, the body that goes worst -- the one whose best probe still reads furthest out of band.
-- What a designer opening a quest file wants to know first.
-- Tier-0 bodies that a quest nonetheless fields by name.
--
-- docs/bestiary.md puts rung 0 off the ladder -- "a prop, an escortee, or a shape worn by Wild
-- Shape" -- and those blueprints author placeholder pools that nothing reads, because
-- models/transform.lua carries the original's across (character_dire_bear says so in a comment above
-- `health = 1`). But several are also named directly in quest compositions, which means those fights
-- really do stand up a one-health bear.
--
-- Excluded from every judgement above, and reported here instead of being quietly rescaled: the fix
-- is a content decision about what those encounters should field, and tuning a number the game
-- ignores would only hide it.
function M.walkPlaceholders()
    local byId = {}
    for _, questId in ipairs(Balance.questOrder()) do
        for _, body in ipairs(Balance.bodiesFor(questId)) do
            local def = Character.defs[body.id]
            local hp = (def and def.stats or {}).health or 0
            -- Only the ones whose pool is a PLACEHOLDER, not every tier-0 body. A straw sentry with
            -- 24 health is an object doing its job and is off the ladder for good reasons; a body
            -- that authored `health = 1` because nothing was supposed to read it is a fight standing
            -- something up with one hit point.
            if Balance.isPlaceholder(body.id) and hp <= 1 and not byId[body.id] then
                byId[body.id] = { id = body.id, quest = questId, hp = hp, tier = def.tier }
            end
        end
    end
    local rows = {}
    for _, row in pairs(byId) do rows[#rows + 1] = row end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end

function M.walkQuests()
    local byQuest = {}
    for _, row in ipairs(M.walkBodies()) do
        local cur = byQuest[row.quest]
        -- Worse = floors, then dominates, then more hits.
        local function rank(r)
            if r.verdict == "floors" then return 3 end
            if r.verdict == "dominates" then return 2 end
            if r.verdict == "too slow" then return 1 end
            return 0
        end
        if not cur or rank(row) > rank(cur)
            or (rank(row) == rank(cur) and row.ex.out.hits > cur.ex.out.hits) then
            byQuest[row.quest] = row
        end
    end

    local rows = {}
    for _, questId in ipairs(Balance.questOrder()) do
        if byQuest[questId] then rows[#rows + 1] = byQuest[questId] end
    end
    return rows
end

-- Per house, per sponsor-quest-count: what the bench and the shelf actually open.
--
-- Counts AFFORDABLE rungs and BUYABLE rows, never permitted ones. A forge ceiling the player has no
-- materials for is not a lever, and Vendor.stock emits a house's whole catalogue with the locked rows
-- flagged -- counting listed rows would report a flat line forever. Same argument
-- tools/progression_report.lua makes for its own buyable-rows count.
--
-- `plain` is the number that matters for cadence: rows gated only on quest count, which a player who
-- has not unlocked the discipline can actually reach. A gate that opens nothing but discipline stock
-- is a quest where the shelf visibly does not move.
function M.walkCadence()
    local rows = {}
    for _, v in ipairs(Vendor.list()) do
        local lineLength = 0
        for _, def in pairs(Quest.defs) do
            if def.sponsor == v.id then lineLength = lineLength + 1 end
        end

        local prevPlain, prevAll = nil, nil
        for done = 0, lineLength do
            local player = Balance.playerAt(math.max(1, done), v.id, done)
            local unlocked = Discipline.unlockedSet(player)
            local levels = Discipline.levelSet(player)

            local plain, all = 0, 0
            for _, entry in ipairs(Vendor.stock(v.id, done, nil, unlocked, levels)) do
                if not entry.locked then
                    all = all + 1
                    local def = entry.item or Item.defs[entry.id]
                    if not (def and def.discipline) then plain = plain + 1 end
                end
            end

            -- The reference weapon of this house's own shelf, for a ceiling that means something.
            local sample = nil
            for _, entry in ipairs(Vendor.stock(v.id, done, nil, unlocked, levels)) do
                local def = entry.item or Item.defs[entry.id]
                if def and def.type == "weapon" and not def.discipline and not entry.locked then
                    sample = def
                    break
                end
            end

            rows[#rows + 1] = {
                vendor = v.id,
                done = done,
                ceiling = sample and Forge.ceilingFor(player, sample) or 0,
                plain = plain,
                all = all,
                openedPlain = prevPlain and (plain - prevPlain) or plain,
                openedAll = prevAll and (all - prevAll) or all,
            }
            prevPlain, prevAll = plain, all
        end
    end
    return rows
end

-- Trail encounters run to a decision through the real turn loop. See the header for what this cannot
-- reach. Deterministic per seed, so two runs of the tool agree.
function M.walkSim(opts)
    opts = opts or {}
    local seeds = opts.seeds or 5
    local EncounterBattle = require("models.encounter_battle")
    local Autobattle = require("models.autobattle")
    local Combat = require("models.combat")
    local Encounter = require("models.encounter")

    local roster = opts.roster or { Balance.REFERENCE.charId, "character_rowan" }
    local rows = {}

    local ids = {}
    for id in pairs(Encounter.defs) do ids[#ids + 1] = id end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local def = Encounter.defs[id]
        if EncounterBattle.eligible(def) then
            local prestige = opts.prestige or def.minPrestige or 1
            local wins, turns, undecided = 0, 0, 0
            for s = 1, seeds do
                local ok, built = pcall(EncounterBattle.build, {
                    encounter = { kind = def.kind or "combat", id = id, tier = def.tier },
                    prestige = prestige,
                    party = roster,
                    seed = s,
                })
                if ok and built then
                    pcall(function()
                        EncounterBattle.autoDeploy(built.combat, built.arena, roster)
                        Combat.openBattle(built.combat)
                        local result, n = Autobattle.run(built.combat)
                        if result == "win" then wins = wins + 1
                        elseif result == nil then undecided = undecided + 1 end
                        turns = turns + (n or 0)
                    end)
                end
            end
            rows[#rows + 1] = {
                id = id, prestige = prestige, seeds = seeds,
                wins = wins, undecided = undecided,
                avgTurns = seeds > 0 and (turns / seeds) or 0,
            }
        end
    end
    return rows
end

-- ---------------------------------------------------------------------------
-- The printer
-- ---------------------------------------------------------------------------

local function hits(n)
    if n == math.huge then return "inf" end
    return tostring(n)
end

local function printFailures(bodies)
    -- INDEPENDENT predicates, not values of one label. A body can be both unhittable and dominating
    -- -- the Grey Knight is exactly that -- and reading them off the single `verdict` string dropped
    -- it out of the unhittable list entirely, because `verdict` reports dominance first. They are
    -- different diagnoses pointing at different numbers, so each is asked separately.
    local walled, unhittable, dominates, harmless = {}, {}, {}, {}
    for _, row in ipairs(bodies) do
        if row.ex.out.floored then
            walled[#walled + 1] = row
            if not row.magicOnly then unhittable[#unhittable + 1] = row end
        end
        if row.dominates then dominates[#dominates + 1] = row end
        if row.ex.back.floored then harmless[#harmless + 1] = row end
    end

    print("")
    print(string.format("WALLED TO STEEL -- every sword, spear and mace floors against these (%d)", #walled))
    print("  This is the reported symptom: the starting company is two melee bodies.")
    if #walled == 0 then
        print("  none.")
    else
        for _, r in ipairs(walled) do
            print(string.format("  p%-2d %-9s %-32s %-34s best melee %-6s %d/hit, %s hits%s",
                r.prestige, r.difficulty or "?", r.id, r.quest, r.physical, r.ex.out.perHit,
                hits(r.ex.out.hits), r.magicOnly and "   (magic still lands)" or ""))
        end
    end

    print("")
    print(string.format("UNHITTABLE -- every probe floors, magic included (%d)", #unhittable))
    if #unhittable == 0 then
        print("  none.")
    else
        for _, r in ipairs(unhittable) do
            print(string.format("  p%-2d %-9s %-32s %-34s %d/hit, %s hits",
                r.prestige, r.difficulty or "?", r.id, r.quest, r.ex.out.perHit,
                hits(r.ex.out.hits)))
        end
    end

    print("")
    print(string.format("DOMINATES -- beats the reference on attack AND armour AND health (%d)", #dominates))
    if #dominates == 0 then
        print("  none.")
    else
        for _, r in ipairs(dominates) do
            local ref = r.ex.reference
            print(string.format("  p%-2d %-32s %-34s  body %d atk / %d mit / %d hp  vs  ref %d / %d / %d",
                r.prestige, r.id, r.quest,
                r.ex.back.budget, r.ex.out.mitigation, r.ex.out.hp,
                ref.budget, ref.mitigation, ref.hp))
        end
    end

    print("")
    print(string.format("HARMLESS -- these floor against the reference loadout (%d)", #harmless))
    print("  Low damage is OFTEN authored intent here -- walls, objects, support units and conjured")
    print("  constructs all say so in their blueprint headers. `by design` marks the ones that declare")
    print("  it (Balance.isNonCombatant); the rest are named in tests/balance_spec.lua's waivers.")
    if #harmless == 0 then
        print("  none.")
    else
        for _, r in ipairs(harmless) do
            print(string.format("  p%-2d %-32s %-34s deals %d/hit, %s hits to fell the avatar%s",
                r.prestige, r.id, r.quest, r.ex.back.perHit, hits(r.ex.back.hits),
                Balance.isNonCombatant(r.id) and "   (by design)" or ""))
        end
    end
end

local function printReference(rows, full)
    print("")
    print("Reference loadout -- what the player throws")
    print(string.format("  %s + %s, %s",
        Balance.REFERENCE.charId, Balance.REFERENCE.weapon, Balance.REFERENCE.armor))
    print("  prestige  lvl  forge  budget  own mit  own hp")
    for _, r in ipairs(rows) do
        if full or r.prestige <= BRIEF_PRESTIGE then
            print(string.format("  %-8d  %-3d  +%-4d  %-6d  %-7d  %d",
                r.prestige, r.level, r.ceiling, r.budget, r.mitigation, r.hp))
        end
    end
end

local function printQuests(rows, full)
    print("")
    print("Per quest -- the body that goes worst")
    print("  p   difficulty  quest                              worst body                        best  /hit  hits  verdict")
    for _, r in ipairs(rows) do
        local flag = ""
        -- An Easy quest fielding something the starting kit cannot hurt is the specific bug this
        -- report was built to find. Mark it so it cannot be scrolled past.
        if r.difficulty == "Easy" and (r.verdict == "floors" or r.verdict == "too slow") then
            flag = "   <-- EASY"
        end
        if full or r.verdict ~= "ok" then
            print(string.format("  %-3d %-11s %-34s %-33s %-5s %-5d %-5s %s%s",
                r.prestige, r.difficulty or "?", r.quest, r.id, r.physical,
                r.ex.out.perHit, hits(r.ex.out.hits), r.verdict, flag))
        end
    end
end

local function printCadence(rows, full)
    print("")
    print("Cadence -- what each quest at a house opens")
    print("  house           done  forge  plain rows  (+new)  all rows  (+new)")
    local silent = {}
    for _, r in ipairs(rows) do
        if full or r.done <= 6 then
            print(string.format("  %-14s  %-4d  +%-4d  %-10d  %-6d  %-8d  %d",
                r.vendor, r.done, r.ceiling, r.plain, r.openedPlain, r.all, r.openedAll))
        end
        if r.done > 0 and r.openedPlain == 0 then silent[#silent + 1] = r end
    end
    print("")
    print(string.format("  Gates opening NO plain (non-discipline) row (%d) -- a quest where the shelf does not move:", #silent))
    if #silent == 0 then
        print("    none.")
    else
        for _, r in ipairs(silent) do
            print(string.format("    %-14s after %d quest%s", r.vendor, r.done, r.done == 1 and "" or "s"))
        end
    end
end

function M.run(args)
    local full, sim, seeds = false, false, 5
    local wantSeeds = false
    for _, a in ipairs(args or {}) do
        if a == "full" then full = true end
        if a == "sim" then sim, wantSeeds = true, true
        elseif wantSeeds and tonumber(a) then seeds = tonumber(a); wantSeeds = false end
    end

    print("")
    print("Balance ledger -- the two scales, measured against each other")
    print(string.format("  %d quests, %d bodies, TTK bands line %d-%d / elite %d-%d / boss %d-%d",
        questCount(), (function()
            local n = 0
            for _ in pairs(Character.defs) do n = n + 1 end
            return n
        end)(),
        Balance.TTK.line.min, Balance.TTK.line.max,
        Balance.TTK.elite.min, Balance.TTK.elite.max,
        Balance.TTK.boss.min, Balance.TTK.boss.max))

    local bodies = M.walkBodies()
    printFailures(bodies)

    local placeholders = M.walkPlaceholders()
    print("")
    print(string.format("PLACEHOLDER STATLINES fielded as live enemies (%d)", #placeholders))
    print("  Tier 0 is off the ladder (docs/bestiary.md): a prop, an escortee, or a shape worn by")
    print("  Wild Shape, whose pools nothing reads because models/transform.lua carries the")
    print("  original's across. A quest naming one by name really does stand up a body with that")
    print("  health. Not rescaled -- the fix is what the encounter should field.")
    if #placeholders == 0 then
        print("  none.")
    else
        for _, r in ipairs(placeholders) do
            print(string.format("  %-32s tier %d, %d hp   first fielded by %s",
                r.id, r.tier or -1, r.hp, r.quest))
        end
    end
    printReference(M.walkReference(), full)
    printQuests(M.walkQuests(), full)
    printCadence(M.walkCadence(), full)

    if sim then
        print("")
        print(string.format("Simulated trail encounters (%d seeds each)", seeds))
        print("  NOTE: EncounterBattle.eligible refuses objectives and escorts, so this covers the")
        print("  road and not the fights that go wrong. The sections above cover those.")
        print("  encounter                             p    wins  undecided  avg turns")
        for _, r in ipairs(M.walkSim({ seeds = seeds })) do
            print(string.format("  %-36s  %-4d %d/%-3d %-10d %.1f",
                r.id, r.prestige, r.wins, r.seeds, r.undecided, r.avgTurns))
        end
    end

    if not full then
        print("")
        print("Pass `full` for every quest and the whole reference curve; `sim [n]` to run the road.")
        print("")
    end
end

return M
