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
local Class = require("models.class")
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
-- Memoized: this is the expensive walk (every body the campaign fields, against four probes apiece,
-- each probe instantiating and folding two units), and M.run asks for it twice -- once directly for
-- the failure sections and once inside walkQuests. Recomputing it was most of the report's runtime,
-- and adding one more section pushed the whole thing past four minutes.
local bodiesCache
function M.walkBodies()
    if bodiesCache then return bodiesCache end
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
    bodiesCache = rows
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
            local unlocked = Class.unlockedSet(player)
            local levels = Class.levelSet(player)

            local plain, all = 0, 0
            for _, entry in ipairs(Vendor.stock(v.id, done, nil, unlocked, levels)) do
                if not entry.locked then
                    all = all + 1
                    local def = entry.item or Item.defs[entry.id]
                    -- "Plain" is the open rack: a ROOT class's stock. Since the fold there is no
                    -- second field to read (docs/class-fold.md).
                    if not (def and Class.isEarned(def.class)) then plain = plain + 1 end
                end
            end

            -- The reference weapon of this house's own shelf, for a ceiling that means something.
            local sample = nil
            for _, entry in ipairs(Vendor.stock(v.id, done, nil, unlocked, levels)) do
                local def = entry.item or Item.defs[entry.id]
                if def and def.type == "weapon" and not Class.isEarned(def.class) and not entry.locked then
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

-- Every priced item's LEVEL-0 magnitude against the gate it unlocks at.
--
-- The question this answers is "does an item's power respect its `unlockQuests`" -- is a thing the
-- shelf opens after nine quests actually better than what it sold on day one, and is anything on the
-- opening shelf so strong the gate behind it means nothing.
--
-- Measured as a share of the WIELDER'S ATTACK STAT at that gate rather than as a raw number, because
-- the raw number is not comparable across the campaign: the same 6 power is half a level-1 body's
-- output and a rounding error at level 40. Share says how much of the blow the ITEM is.
--
-- Reported, not asserted, and the reason is riders. weapon_quietus is a gate-6 discipline dagger at
-- 330 gold with power 5 -- less than a 60-gold iron sword -- because what it sells is a kill that
-- cannot be revived. A pure-magnitude rule would call that broken every time, and it is not; a human
-- reads the outliers and decides which are paying for something.
function M.walkItems()
    local rows = {}
    for id, def in pairs(Item.defs) do
        if def.price then
            local gate = def.unlockQuests or 0
            local prestige = math.max(1, gate)

            -- The headline magnitude, at level 0, and which axis it sits on.
            local item = Item.instantiate(id, 1, 0)
            local ab = item.activeAbility
            local kind, mag
            if ab and type(ab.damage) == "number" then kind, mag = "damage", ab.damage
            elseif ab and type(ab.healing) == "number" then kind, mag = "healing", ab.healing
            elseif item.bonus and type(item.bonus.defense) == "number" and item.bonus.defense > 0 then
                kind, mag = "defense", item.bonus.defense
            elseif item.bonus and type(item.bonus.magicDefense) == "number" and item.bonus.magicDefense > 0 then
                kind, mag = "magicDefense", item.bonus.magicDefense
            end

            if kind and mag then
                -- The body's own contribution at this gate: what the item is measured against.
                local magical = false
                for _, t in ipairs(item.tags or {}) do
                    if t == "magical" then magical = true end
                end
                local ref = Balance.refChar(prestige, magical and "mage" or nil)
                local stat
                if kind == "defense" then stat = ref.stats.defense
                elseif kind == "magicDefense" then stat = ref.stats.magicDefense
                else stat = magical and ref.stats.magicDamage or ref.stats.damage end

                rows[#rows + 1] = {
                    id = id, gate = gate, price = def.price, kind = kind, mag = mag,
                    class = def.class, discipline = Class.isEarned(def.class) and def.class or nil,
                    family = (item.tags or {})[1],
                    stat = stat, share = stat > 0 and (mag / stat) or 0,
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.gate ~= b.gate then return a.gate < b.gate end
        return a.id < b.id
    end)
    return rows
end

-- Does the SHOP keep the player in pace, and does the FORGE bridge the gaps between purchases?
--
-- The intended loop is that upgrades come mostly from the shelf, and the bench keeps what you already
-- carry relevant until the next one arrives. That makes the question "does a weapon bought at gate N
-- still pull its weight at gate N+1, N+2..." -- NOT "can the player forge everything to the top",
-- which is what the forge-economy section below measures and is the wrong question for this loop.
--
-- So: walk each class's shelf gate by gate. At each, take the best plain weapon on sale, and follow
-- it FORWARD as the wielder's stat grows -- unforged, and forged to the ceiling -- until the next
-- weapon appears. A share that sags below the family's level before the next purchase is a stretch
-- where the player is falling behind; whether the forge can cover it is exactly what the two columns
-- answer.
function M.walkPace()
    local rows = {}
    for _, v in ipairs(Vendor.list()) do
        local class = v.class
        if class then
            -- Every plain damaging thing of this class, by the gate that opens it -- weapons AND
            -- abilities. For half the houses the ability IS the weapon: the Arcanum sells no blade
            -- better than a gate-0 wand until quest 10, and reading weapons alone reported a
            -- nine-quest drought where its player was actually buying Fire Bolt, then Fireball.
            local byGate = {}
            for id, def in pairs(Item.defs) do
                if def.price and (def.type == "weapon" or def.type == "ability")
                    and not Class.isEarned(def.class) and def.class == class then
                    local g = def.unlockQuests or 0
                    local item = Item.instantiate(id, 1, 0)
                    local power = (item.activeAbility and item.activeAbility.damage) or 0
                    if type(power) == "number" and power > 0 then
                        if not byGate[g] or power > byGate[g].power then
                            byGate[g] = { id = id, power = power, def = def }
                        end
                    end
                end
            end
            local gates = {}
            for g in pairs(byGate) do gates[#gates + 1] = g end
            table.sort(gates)

            for i, g in ipairs(gates) do
                local entry = byGate[g]
                local nextGate = gates[i + 1]
                local fam = Balance.familyOf(entry.id)

                -- How the weapon reads at the gate AFTER it -- the far end of the stretch it has to
                -- cover. Unforged, and taken to the ceiling a player of that standing could reach.
                local until_ = nextGate or 12
                -- The family's level is read AT THE SLOT this stretch ends on, not once for the whole
                -- family: the ladder climbs per slot now (Balance.slotTarget), so a single figure would
                -- price the last shelf against the first one's target.
                local level = fam and Balance.familyShareAt(fam, until_)
                local stat = Balance.wielderStatFor({ tags = entry.def.tags,
                    unlockQuests = until_ })
                local ceiling = Balance.forgeCeiling(entry.id, math.max(1, until_), until_)
                local forged = Item.instantiate(entry.id, 1, ceiling)
                local forgedPower = (forged.activeAbility and forged.activeAbility.damage) or entry.power

                rows[#rows + 1] = {
                    vendor = v.id, class = class, gate = g, id = entry.id,
                    nextGate = nextGate, gap = until_ - g,
                    level = level,
                    atBuy = stat > 0 and entry.power / stat or 0,
                    plainEnd = stat > 0 and entry.power / stat or 0,
                    forgedEnd = stat > 0 and forgedPower / stat or 0,
                    ceiling = ceiling,
                }
            end
        end
    end
    return rows
end

-- Can a run PAY for the rungs it opens?
--
-- The bands assume gear as bought (Balance.FORGE_BASELINE = 0), so forging is headroom rather than a
-- toll -- but headroom nobody can reach is not headroom, it is a dead lever, which is what the forge
-- ceiling was before it started following the shelf. This measures the other half: what one run of a
-- house's quest actually hands over in materials, against what the next rung on that house's gear
-- costs.
--
-- The payout is the FLOOR, deliberately: Spoils.materials is computed and never rolled, so this is
-- what a run pays even if the player walks past every cache. Caches add 1-4 craft and 1-3 house on
-- top (models/overworld.lua), and they are the reward for leaving the path, so counting them here
-- would price the bench at the exploring player and quietly tax everyone else.
function M.walkForgeEconomy()
    local Spoils = require("models.spoils")
    local Material = require("models.material")

    local rows = {}
    for _, v in ipairs(Vendor.list()) do
        local house = Material.houseFor and Material.houseFor(v.class or v.id) or nil

        -- A representative plain class weapon of this house -- what the player is actually forging.
        local sample
        for id, def in pairs(Item.defs) do
            if def.class and Forge.houseVendorFor(def.class) == v.id
                and def.type == "weapon" and not Class.isEarned(def.class) and def.price
                and (def.unlockQuests or 0) == 0 then
                if not sample or id < sample.id then sample = { id = id, def = def } end
            end
        end
        if sample then
            -- WALKED ALONG THE HOUSE'S OWN LINE, and at each standing priced the DEEPEST RUNG THAT
            -- STANDING JUST OPENED -- which is the question in the section title.
            --
            -- It used to sample the standings { 0, 2, 5, 9 } and forge the item to `done` as well,
            -- because under the retired one-rung-per-quest ceiling those were the same number. They are
            -- not any more (models/forge.lua), and a house asks for six errands, so the old sample
            -- priced two rungs no line can reach against a standing no player can hold.
            local rungs = require("models.errand").tiers(v.id)
            for done = 0, rungs do
                local player = Balance.playerAt(math.max(1, done), v.id, done)
                player.materials = {}
                local ceiling = Forge.ceilingFor(player, sample.def)
                local item = Item.instantiate(sample.id, 1, math.max(0, ceiling - 1))
                local cost = Forge.upgradeCost(player, item)

                -- One run of this house's line, at its floor: an objective plus a couple of road
                -- fights, one of them elite.
                local earned = {}
                local function bank(t)
                    for id, n in pairs(t) do earned[id] = (earned[id] or 0) + n end
                end
                bank(Spoils.materials({ kind = "objective", tier = 2, houseMaterial = house }))
                bank(Spoils.materials({ kind = "elite", tier = 2, houseMaterial = house }))
                for _ = 1, 4 do bank(Spoils.materials({ kind = "combat", tier = 1 })) end

                -- Runs needed to cover the worst-supplied material in the bill.
                local runs = 0
                for id, need in pairs((cost and cost.materials) or {}) do
                    local per = earned[id] or 0
                    local r = per > 0 and math.ceil(need / per) or math.huge
                    if r > runs then runs = r end
                end

                rows[#rows + 1] = {
                    vendor = v.id, done = done, item = sample.id,
                    target = (item.level or 0) + 1,
                    locked = cost and cost.locked,
                    materials = cost and cost.materials or {},
                    earned = earned,
                    runs = runs,
                }
            end
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

    -- Level-0 magnitude against the gate that opens it.
    local items = M.walkItems()
    local byGate = {}
    for _, r in ipairs(items) do
        local g = byGate[r.gate] or { n = 0, sum = 0, shares = {}, rows = {} }
        g.n, g.sum = g.n + 1, g.sum + r.share
        g.shares[#g.shares + 1] = r.share
        g.rows[#g.rows + 1] = r
        byGate[r.gate] = g
    end
    local gates = {}
    for g in pairs(byGate) do gates[#gates + 1] = g end
    table.sort(gates)

    print("")
    print("Item power vs its gate -- level-0 magnitude as a share of the wielder's own stat")
    print("  A weapon at 0.50 contributes half as much as the body swinging it. The point is whether")
    print("  the share HOLDS as gates rise: a later gate that sells a smaller share is a purchase")
    print("  that is a downgrade, and an opening gate that sells a large one makes the gates behind")
    print("  it meaningless. Riders are not visible here -- see the outliers below.")
    -- Split by KIND as well as by gate. A falling overall median could just be a changing mix --
    -- late gates holding more armour, whose numbers are naturally smaller than a weapon's -- and that
    -- would be an artefact of the measurement rather than a fact about the shelf.
    local KINDS = { "damage", "healing", "defense", "magicDefense" }
    local function medianOf(list)
        if #list == 0 then return nil end
        table.sort(list)
        return list[math.ceil(#list / 2)]
    end

    print("  gate  n    median share   range          per kind (median share)")
    for _, g in ipairs(gates) do
        local e = byGate[g]
        table.sort(e.shares)
        local med = e.shares[math.ceil(#e.shares / 2)]
        local bits = {}
        for _, kind in ipairs(KINDS) do
            local sub = {}
            for _, r in ipairs(e.rows) do
                if r.kind == kind then sub[#sub + 1] = r.share end
            end
            local m = medianOf(sub)
            if m then bits[#bits + 1] = string.format("%s %.2f (%d)", kind:sub(1, 3), m, #sub) end
        end
        print(string.format("  %-5d %-4d %-14.2f %.2f - %-8.2f %s",
            g, e.n, med, e.shares[1], e.shares[#e.shares], table.concat(bits, "  ")))
    end

    -- Outliers: the items furthest from their own gate's median, both directions.
    local flagged = {}
    for _, g in ipairs(gates) do
        local e = byGate[g]
        table.sort(e.shares)
        local med = e.shares[math.ceil(#e.shares / 2)]
        for _, r in ipairs(e.rows) do
            if med > 0 and (r.share > med * 2 or r.share < med * 0.5) then
                r.med = med
                flagged[#flagged + 1] = r
            end
        end
    end
    table.sort(flagged, function(a, b)
        local ra = a.share / (a.med > 0 and a.med or 1)
        local rb = b.share / (b.med > 0 and b.med or 1)
        return ra > rb
    end)
    -- The LADDER each family is held to, slot by slot. Printed in full rather than as one figure
    -- because the target climbs per slot now: the interesting property is that the last rung equals the
    -- base weapon fully forged, and that is only visible with both ends on screen.
    local anchors = Balance.slotAnchors()
    local fams = {}
    for fam in pairs(anchors) do fams[#fams + 1] = fam end
    table.sort(fams, function(a, b) return anchors[a].base > anchors[b].base end)
    local maxSlot = Balance.maxSlot()
    print("")
    print("  Family ladders -- the unforged power each slot names, from the family's BASE weapon")
    print("  unforged (slot 0) to that same weapon FULLY FORGED (the last slot). docs/weapons.md's S1")
    print("  rows set the low end, so a greatsword stays a greatsword and a dagger stays a dagger.")
    local hdr = "    family       "
    for s = 0, maxSlot do hdr = hdr .. string.format("%4d", s) end
    print(hdr .. "   read off")
    for _, fam in ipairs(fams) do
        local row = string.format("    %-12s ", fam)
        for s = 0, maxSlot do row = row .. string.format("%4d", Balance.slotTarget(fam, s) or 0) end
        local base = Balance.FAMILY_BASE[fam]
        print(row .. "   " .. (base and ("base " .. base) or "median of the early ability shelf"))
    end

    print("")
    print(string.format("  Outliers -- more than 2x or under half their own gate's median (%d):", #flagged))
    if #flagged == 0 then
        print("    none.")
    else
        for _, r in ipairs(flagged) do
            print(string.format("    gate %-3d %-34s %-12s %3d (%.2f vs %.2f median) %s%s",
                r.gate, r.id, r.kind, r.mag, r.share, r.med,
                r.share > r.med and "STRONG" or "weak  ",
                r.discipline and ("  [" .. r.discipline .. "]") or ""))
        end
    end

    print("")
    print("Keeping pace -- the shop upgrades you, the forge bridges the gap between purchases")
    print("  For each class's shelf: the best plain weapon at a gate, then how it reads by the time")
    print("  the NEXT weapon arrives -- unforged, and forged to the ceiling. `level` is that family's")
    print("  own share. A plain figure well under it is a stretch the bench has to cover.")
    print("  class      gate  weapon                        next  gap  level  plain  forged  verdict")
    for _, r in ipairs(M.walkPace()) do
        local lvl = r.level or 0
        local verdict
        if r.gap <= 0 then verdict = "-"
        elseif r.forgedEnd >= lvl * 0.85 and r.plainEnd >= lvl * 0.85 then verdict = "holds unforged"
        elseif r.forgedEnd >= lvl * 0.85 then verdict = "forge covers it"
        elseif Balance.MAGNITUDE_WAIVERS[r.id] then
            -- A waived outlier: its blueprint argues the small number in prose and raising it would
            -- delete what the item is. Three items qualify; the reason is in Balance.MAGNITUDE_WAIVERS.
            verdict = "waived: the number is the price"
        else verdict = "FALLS BEHIND"
        end
        print(string.format("  %-10s %-5d %-29s %-5s %-4d %-6.2f %-6.2f %-7.2f %s",
            r.class, r.gate, r.id:gsub("^weapon_", ""),
            r.nextGate and tostring(r.nextGate) or "(last)", r.gap,
            lvl, r.plainEnd, r.forgedEnd, verdict))
    end

    print("")
    print("Kept-up gear -- what the bands DO NOT measure")
    print("  Balance.TTK grades every body against Balance.REFERENCE: the avatar with an iron sword, a")
    print("  slot-0 weapon. That is the right fixed yardstick for catching a body that drifts, but the")
    print("  slot ladder raised the late shelf well above it -- so a green band means 'fair against the")
    print("  OPENING shelf' and says nothing about a player carrying what they have earned. This is that")
    print("  second question: the same bodies, measured with the deepest weapon of the probe's family a")
    print("  player at that standing could have bought (Balance.progressedWeapon).")
    print("  quest                              body                  role   ref  kept  band     verdict")
    local overshoot, rows2 = 0, 0
    for _, questId in ipairs(Balance.questOrder()) do
        local prestige = Balance.prestigeFor(questId)
        local sponsorDone = Balance.sponsorDoneFor(questId)
        for _, body in ipairs(Balance.bodiesFor(questId)) do
            if body.role and not Balance.isPlaceholder(body.id) then
                local m = Balance.measure(prestige, body.id, body.role, { sponsorDone = sponsorDone })
                local kept = Balance.progressedExchange(prestige, body.id, m.physical,
                    { sponsorDone = sponsorDone })
                if kept then
                    local band = Balance.TTK[body.role] or Balance.TTK.line
                    local refHits, keptHits = m.ex.out.hits, kept.out.hits
                    -- Only the rows where the kept-up loadout leaves the band the reference sat inside.
                    -- Everything else is the system working and does not need a line.
                    if refHits >= band.min and keptHits < band.min then
                        rows2 = rows2 + 1
                        overshoot = overshoot + 1
                        if rows2 <= 25 then
                            print(string.format("  %-34s %-21s %-6s %3d  %4d  %d-%-4d %s",
                                questId:gsub("^quest_", ""), body.id:gsub("^character_", ""),
                                body.role, refHits, keptHits, band.min, band.max,
                                "falls faster than its rung"))
                        end
                    end
                end
            end
        end
    end
    if overshoot == 0 then
        print("    none -- every body still lands inside its band with a kept-up weapon.")
    else
        print(string.format("    %d body/quest pairs fall BELOW their band once the player is carrying the",
            overshoot))
        print("    shelf they earned. Not automatically a defect -- being ahead of the curve is what a")
        print("    purchase is FOR (Balance.FORGE_BASELINE says the same about the forge) -- but it is the")
        print("    number to argue about if the late campaign starts feeling weightless.")
        if rows2 > 25 then print(string.format("    (%d more not shown)", rows2 - 25)) end
    end

    print("")
    print("Forge economy -- can a run pay for the rung it opened?")
    print("  Materials from ONE run at its floor (objective + elite + 4 road fights, no caches),")
    print("  against the next rung on that house's opening weapon. `runs` is how many such runs the")
    print("  worst-supplied line of the bill needs. Caches pay 1-4 craft / 1-3 house on top.")
    print("  `after` is errands run at that house; `rung` is the deepest level that standing opens.")
    print("  house           after  rung  runs  bill")
    local econ = M.walkForgeEconomy()
    local worst, deepest = 0, 0
    for _, r in ipairs(econ) do
        if r.runs ~= math.huge then
            if r.done == 0 and r.runs > worst then worst = r.runs end
            if r.runs > deepest then deepest = r.runs end
        end
    end
    for _, r in ipairs(econ) do
        local bits = {}
        for id, n in pairs(r.materials) do
            bits[#bits + 1] = string.format("%dx %s (have %d)", n, id:gsub("^material_", ""), r.earned[id] or 0)
        end
        table.sort(bits)
        print(string.format("  %-14s  %-5d  +%-4d %-5s %s%s",
            r.vendor, r.done, r.target, r.runs == math.huge and "NEVER" or tostring(r.runs),
            #bits > 0 and table.concat(bits, ", ") or "(no material cost)",
            r.locked and "   [past the ceiling]" or ""))
    end
    print("")
    print(string.format("  ONE item keeps pace: %d run per early rung, %d at the top of the ladder,",
        worst, deepest))
    print("  against a house line of six errands. The bill grows with depth (t+1 craft,")
    print("  ceil(t/2) house) while the payout per run is flat, which is the right shape -- a deep")
    print("  rung should cost more runs than a shallow one.")
    print("  The constraint is BREADTH, not depth: a run funds about two early rungs, so a company")
    print("  of four carrying two forgeables each cannot be kept level across the board. That is a")
    print("  choice about who gets the good gear, which is the intended shape of the decision.")

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
