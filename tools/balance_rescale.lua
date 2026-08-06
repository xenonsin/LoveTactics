-- Balance rescale: run with
--
--     & "E:\LOVE\lovec.exe" . balance-rescale [apply]
--
-- Dry run by default -- it prints every edit it WOULD make and touches nothing. `apply` writes.
--
-- WHAT THIS IS FOR. Combat's damage formula is purely subtractive, so weapon power and body armour
-- are quantities in the same unit; they were authored on scales about 2x apart, and the result was a
-- level-1 party dealing the floor of 1 to the second line's first armoured body. models/balance.lua
-- is the shared unit that finally lets the two be compared, tools/balance_report.lua reads it, and
-- this is the pass that brings the blueprints into the band tests/balance_spec.lua enforces.
--
-- FOUR PASSES, IN THIS ORDER, because each depends on the one before:
--
--   1 armour    no single piece takes more than Balance.ARMOR_SHARE of the attack budget off one
--               weapon (defense bonus PLUS every resist that weapon's tags match). Must run first:
--               a body's armour is part of its mitigation, so pass 2 cannot know its target until
--               the coats have settled.
--   2 defense   a body's TOTAL mitigation leaves enough damage to fell it inside its role's TTK band.
--   3 attack    a body may not out-hit the reference loadout it is fielded against.
--   4 mirror    a body that now floors AGAINST the reference gets its attack raised back into band.
--               Runs last because it is the correction to pass 3 overshooting, and it needs the
--               armour and defense numbers final to know what it is shooting at.
--
-- WHAT IT DELIBERATELY DOES NOT TOUCH. Growth.ENEMY_DAMAGE_GROWTH, Growth.ENEMY_LEVEL_LAG and
-- Growth.meetsSurvivabilityFloor are per-LEVEL rates and are settled design (models/growth.lua:29-60
-- argues them at length). This pass moves BASE magnitudes only. The two are orthogonal -- which is
-- exactly what makes this safe: tests/growth_spec.lua cannot notice a single edit made here.
--
-- HOW IT EDITS. It rewrites the literal in the blueprint's source text rather than regenerating the
-- file, so every comment an author wrote survives the pass. Nothing is written that does not parse.

local Balance = require("models.balance")
local Character = require("models.character")
local Item = require("models.item")
local Growth = require("models.growth")
local Quest = require("models.quest")

local M = {}

-- ---------------------------------------------------------------------------
-- Source I/O (the shape tools/unlock_rescale.lua established)
-- ---------------------------------------------------------------------------

local function sourcePath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

local function readFile(rel)
    local f = io.open(sourcePath(rel), "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local function writeFile(rel, text)
    -- Never write a blueprint that would not parse -- the rewriter edits source text, so this is the
    -- one guard between a bad pattern and a broken data file.
    local ok, err = loadstring(text)
    assert(ok, "refusing to write invalid Lua to " .. rel .. ": " .. tostring(err))
    local f = assert(io.open(sourcePath(rel), "wb"))
    f:write(text)
    f:close()
end

local function charPath(id) return "data/characters/" .. id .. ".lua" end

-- What level-up growth has ADDED to each stat by the level a body is met at.
--
-- Every measurement in models/balance.lua is taken on a GROWN body -- Growth.spawn bakes the class
-- table's per-level gains into char.stats before anything is measured -- while every edit here is
-- written into a BLUEPRINT literal, which is the level-1 value. The two are different numbers and
-- conflating them is silent: an early version read `character_bastion_sworn` as 128 health (grown),
-- solved for 80, and wrote 80 over a blueprint that said 74 -- a cut presented as a cut, applied to
-- the wrong quantity, landing somewhere nobody chose.
--
-- So: solve in grown space, then subtract this delta to get the blueprint value.
local function growthDelta(id, level)
    local base = Character.instantiate(id)
    local grown = Growth.spawn(id, level)
    local out = {}
    for stat, v in pairs(grown.stats) do
        local g = (type(v) == "table") and v.max or v
        local b = base.stats[stat]
        b = (type(b) == "table") and b.max or b
        if type(g) == "number" and type(b) == "number" then out[stat] = g - b end
    end
    return out
end

-- Does this blueprint state `stat` as a literal we can rewrite?
--
-- A derived blueprint copies its base's stats and then overrides a few (character_saber_bout takes
-- everything from character_saber and writes only `bout.stats.health = 110`), so which knobs are
-- available differs per file. Asking before solving lets the solver put the whole correction into a
-- knob that exists, instead of proposing an edit to one that does not and giving up -- and it keeps
-- the tool from reaching into a COMPANION's blueprint to retune an enemy derived from her.
local function hasLiteral(path, stat)
    local text = path and readFile(path)
    if not text then return false end
    return text:find("%f[%w]" .. stat .. "%s*=%s*%-?%d+") ~= nil
end

-- The most of a body's health one pass may take off. Beyond this the numbers stop describing the same
-- creature, and the excess is nearly always its LOADOUT rather than its statline.
local HEALTH_CUT_FLOOR = 0.6

local ITEM_DIRS = { "weapon", "armor", "utility", "consumable", "ability" }
local function itemPath(id)
    for _, dir in ipairs(ITEM_DIRS) do
        local rel = "data/items/" .. dir .. "/" .. id .. ".lua"
        if love.filesystem.getInfo("data/items/" .. dir .. "/" .. id .. ".lua") then return rel end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Rewriters
-- ---------------------------------------------------------------------------

-- `defense = 14` -> `defense = 3`, inside the stats block. Anchored on the stat NAME followed by a
-- plain number, first occurrence only: a blueprint states each stat once, and the comments around
-- them frequently mention other numbers.
local function rewriteStat(text, stat, value)
    local out, n = text:gsub("(%f[%w]" .. stat .. "%s*=%s*)%-?%d+", "%1" .. value, 1)
    if n ~= 1 then return nil end
    return out
end

-- `Curve.ramp(8, 18)` -> `Curve.ramp(4, 14)`, keeping the SPAN so the ladder still moves a point per
-- forge level (models/curve.lua asserts top >= base + 10) and a rung never buys nothing. `Curve.ramp(13)`
-- is the one-arg doubling form; it is rewritten to the explicit two-arg form so the span is visible.
local function rewriteRamp(text, field, base, top)
    local pattern = "(" .. field .. "%s*=%s*Curve%.ramp%()%s*%-?%d+%s*,?%s*%-?%d*%s*(%))"
    local out, n = text:gsub(pattern, "%1" .. base .. ", " .. top .. "%2", 1)
    if n ~= 1 then return nil end
    return out
end

-- `slash = 3` inside a resist table.
local function rewriteResist(text, tag, value)
    local out, n = text:gsub("(%f[%w]" .. tag .. "%s*=%s*)%-?%d+", "%1" .. value, 1)
    if n ~= 1 then return nil end
    return out
end

-- ---------------------------------------------------------------------------
-- The measurement each pass acts on
-- ---------------------------------------------------------------------------

-- Every body the campaign fields, at the standing it is met at, deduplicated to the HARDEST
-- appearance. A body used by six quests is one blueprint and gets one number, and the binding case is
-- the earliest/weakest standing it shows up at -- fix that and the later ones follow.
local function bodySites()
    local byId = {}
    for _, questId in ipairs(Balance.questOrder()) do
        local prestige = Balance.prestigeFor(questId)
        local sponsorDone = Balance.sponsorDoneFor(questId)
        for _, body in ipairs(Balance.bodiesFor(questId)) do
            local cur = byId[body.id]
            -- A transform shape's statline is a placeholder nothing reads (Balance.isPlaceholder).
            -- Rescaling it would be tuning a number the game ignores, and its 1 health would drag
            -- every solve toward nonsense. tools/balance_report.lua names them instead.
            --
            -- A COMPANION is skipped for the opposite reason: its statline is read constantly, just
            -- not as an enemy's. Several are fought once before they join, and retuning Rowan because
            -- she is briefly an opponent would weaken the knight the player keeps.
            if Balance.isPlaceholder(body.id) or Balance.isCompanion(body.id) then
                -- skipped
            elseif not cur or prestige < cur.prestige then
                byId[body.id] = {
                    id = body.id, role = body.role, quest = questId,
                    prestige = prestige, sponsorDone = sponsorDone,
                }
            end
        end
    end
    local list = {}
    for _, row in pairs(byId) do list[#list + 1] = row end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- ---------------------------------------------------------------------------
-- Pass 1 -- armour
-- ---------------------------------------------------------------------------

function M.walkArmor()
    local edits = {}
    local ids = {}
    for id, def in pairs(Item.defs) do
        if def.type == "armor" then ids[#ids + 1] = id end
    end
    table.sort(ids)

    for _, id in ipairs(ids) do
        local def = Item.defs[id]
        -- The earlier of "when you could buy it" and "when it is first swung at you"
        -- (Balance.itemPrestige), which tests/balance_spec.lua judges it at too.
        local prestige = Balance.itemPrestige(id, def)

        -- The worst probe decides, since the cap is "no single weapon meets a wall".
        local worst, worstProbe, cap = 0, nil, nil
        for _, probeName in ipairs(Balance.PROBE_ORDER) do
            local probe = Balance.PROBES[probeName]
            local budget = (Balance.attackBudget(prestige, { probe = probe }))
            local item = Item.instantiate(id, 1, 0)
            local statName = probe.magical and "magicDefense" or "defense"
            local total = (item.bonus and item.bonus[statName]) or 0
            for _, t in ipairs(probe.tags) do
                total = total + ((item.resist and item.resist[t]) or 0)
            end
            if total > worst then
                worst, worstProbe, cap = total, probe, budget * Balance.ARMOR_SHARE
            end
        end

        if worstProbe and worst > cap then
            local over = worst - math.floor(cap)
            local statName = worstProbe.magical and "magicDefense" or "defense"
            local raw = def.bonus and def.bonus[statName]
            local edit = { id = id, path = itemPath(id), probe = worstProbe, total = worst, cap = cap }

            -- Take the reduction out of the DEFENSE BONUS first: it is the larger, curve-driven half,
            -- and resists carry the armour's identity (a coat that stops slash should keep stopping
            -- slash). Only if the bonus cannot absorb it all do the resists give ground.
            if type(raw) == "table" then
                local base, top = raw[1], raw[#raw]
                local span = top - base
                local newBase = math.max(0, base - over)
                if newBase ~= base then
                    edit.ramp = { field = statName, base = newBase, top = newBase + span }
                    over = over - (base - newBase)
                end
            elseif type(raw) == "number" and raw > 0 then
                local newVal = math.max(0, raw - over)
                edit.flat = { field = statName, value = newVal }
                over = over - (raw - newVal)
            end

            -- Anything still over comes off the matching resists, largest first.
            if over > 0 then
                edit.resists = {}
                local tags = {}
                for _, t in ipairs(worstProbe.tags) do
                    local r = (def.resist or {})[t]
                    if r and r > 0 then tags[#tags + 1] = { tag = t, value = r } end
                end
                table.sort(tags, function(a, b) return a.value > b.value end)
                for _, entry in ipairs(tags) do
                    if over <= 0 then break end
                    local take = math.min(over, entry.value)
                    edit.resists[#edit.resists + 1] = { tag = entry.tag, value = entry.value - take }
                    over = over - take
                end
            end

            edits[#edits + 1] = edit
        end
    end
    return edits
end

-- ---------------------------------------------------------------------------
-- Pass 2 -- innate defense
-- ---------------------------------------------------------------------------

-- Defense AND health, solved together, because they are the same knob wearing two hats: a body is
-- "too tough" when `hp / (budget - mitigation)` overshoots its band, and that fraction has a term on
-- each side of the line.
--
-- Taking it all out of defense was the first attempt and it produced nonsense -- a Champion and a
-- Forsworn Captain both driven to defense ZERO -- because their real excess is 130 health measured
-- against an 8-hit band, not their armour. Worse, a body's WORN gear is part of its mitigation and
-- pass 1 owns that; once the coat alone exceeds what the band allows, no innate number can fix it and
-- the solver has to reach for health or give up.
--
-- So: lower innate defense as far as the gear underneath it permits, then move health to land the
-- band. Health moves in BOTH directions -- a body dying inside its minimum is as much a miss as one
-- that will not fall, and this is where the "too fast" half of the TTK case is answered.
function M.walkToughness()
    local edits = {}
    for _, site in ipairs(bodySites()) do
        local row = Balance.measure(site.prestige, site.id, site.role,
            { sponsorDone = site.sponsorDone })
        local band = Balance.TTK[site.role]
        local ex = row.ex
        local def = Character.defs[site.id]

        local statName = ex.probe.magical and "magicDefense" or "defense"
        -- Everything below is in GROWN space, matching what Balance measured; growthDelta converts
        -- back to blueprint literals at the end.
        local level = Growth.levelForPrestige(site.prestige)
        local delta = growthDelta(site.id, level)
        local innate = ((def.stats and def.stats[statName]) or 0) + (delta[statName] or 0)
        -- What the GEAR contributes. Pass 1 owns this number; here it is a floor under the solve.
        local worn = ex.out.mitigation - innate

        local needPerHit = math.ceil(ex.out.hp / band.max)
        local allowed = ex.out.budget - needPerHit

        -- Only move a stat this file actually states. A derived enemy whose defense lives on a
        -- COMPANION's blueprint must not drag that companion down with it; the correction goes into
        -- whatever knob it does own, which for those is health.
        local path = charPath(site.id)
        local canDefense = hasLiteral(path, statName)
        local newInnate = canDefense
            and math.max(0, math.min(innate, allowed - worn))
            or innate

        local newMit = worn + newInnate
        local perHit = math.max(1, ex.out.budget - newMit)
        local hp = ex.out.hp

        -- hits = ceil(hp / perHit), so the band translates to
        --     perHit * (min - 1) < hp <= perHit * max
        -- and NOT `hp >= perHit * min`, which was the first version and is wrong at the bottom end: a
        -- 14-health imp felled in one blow is already inside a 1-2 band, and that formula doubled its
        -- health to force a second swing out of it.
        local lowest = perHit * (band.min - 1) + 1
        local highest = perHit * band.max
        local newHp = math.max(lowest, math.min(hp, highest))

        -- Back to BLUEPRINT space -- what the literal in the file has to say for the grown body to
        -- land where the solve wants it.
        local baseInnate = ((def.stats and def.stats[statName]) or 0)
        local baseHp = (def.stats and def.stats.health) or 0
        local newBaseInnate = math.max(0, newInnate - (delta[statName] or 0))
        local newBaseHp = newHp - (delta.health or 0)

        -- Never cut a body to a sliver in one pass. When its WORN gear alone exceeds what the band
        -- allows, no innate number can fix it and health is the only knob left -- which turns an
        -- armoured captain into a 32-health one. Clamp the cut and let it report as over-armoured
        -- instead: the real fix is its loadout, and that is a content decision this tool must not make.
        local floorHp = math.floor(baseHp * HEALTH_CUT_FLOOR)
        local overArmoured = newBaseHp < floorHp
        if overArmoured then newBaseHp = floorHp end

        -- And never leave the rung the blueprint DECLARES. docs/bestiary.md binds each tier to a
        -- health band (Balance.HEALTH_BANDS) and tests/bestiary_spec.lua fails the build over it -- an
        -- earlier run of this pass cut a tier-3 captain to 58, straight through an 81 floor, and the
        -- balance suite went green while the bestiary suite went red. The band is stated in blueprint
        -- space, which is why this clamp comes after the conversion above.
        local rung = Balance.HEALTH_BANDS[def.tier]
        local bandLimited = false
        if rung then
            local clamped = math.max(rung[1], math.min(newBaseHp, rung[2]))
            if clamped ~= newBaseHp then
                bandLimited = true
                newBaseHp = clamped
            end
        end

        if newBaseInnate ~= baseInnate or newBaseHp ~= baseHp then
            local fields = {}
            if newBaseInnate ~= baseInnate then
                fields[#fields + 1] = { stat = statName, from = baseInnate, to = newBaseInnate }
            end
            if newBaseHp ~= baseHp then
                fields[#fields + 1] = { stat = "health", from = baseHp, to = newBaseHp }
            end
            local note = ""
            if overArmoured then note = "  [OVER-ARMOURED: fix its loadout]"
            elseif bandLimited then note = "  [held to its tier's health band]" end
            edits[#edits + 1] = {
                id = site.id, path = charPath(site.id), fields = fields,
                role = site.role, prestige = site.prestige,
                overArmoured = overArmoured, bandLimited = bandLimited,
                was = string.format("grown %d hp / %d mit vs %d budget%s", hp, ex.out.mitigation,
                    ex.out.budget, note),
            }
        end
    end
    table.sort(edits, function(a, b) return a.id < b.id end)
    return edits
end

-- ---------------------------------------------------------------------------
-- Pass 3 -- attack, capped
-- ---------------------------------------------------------------------------

function M.walkAttack()
    local edits = {}
    for _, site in ipairs(bodySites()) do
        local row = Balance.measure(site.prestige, site.id, site.role,
            { sponsorDone = site.sponsorDone })
        local ex = row.ex

        -- Only for a body that actually DOMINATES -- which Balance.dominates limits to the
        -- protagonist's own rank and below. An elite or a boss out-hitting one avatar is what an
        -- elite is; capping every body at the reference's swing instead drove a Champion's greatsword
        -- damage to 0 for the crime of being a greatsword.
        --
        -- Pass 2 has already taken the armour and health axes down, so reaching here means attack is
        -- the one still standing, and trimming it to just under the reference's breaks the tie.
        if Balance.dominates(ex, site.role) and ex.back.budget >= ex.reference.budget then
            local def = Character.defs[site.id]
            local magical = false
            for _, t in ipairs(ex.backTags or {}) do
                if t == "magical" then magical = true end
            end
            local statName = magical and "magicDamage" or "damage"
            -- A RELATIVE adjustment, so no growth conversion is needed: level-up gains are additive,
            -- and taking `over` off the blueprint takes exactly `over` off the grown body too. (Pass 2
            -- solves for an absolute target instead and does have to convert -- see growthDelta.)
            local stat = (def.stats and def.stats[statName]) or 0
            local over = (ex.back.budget - ex.reference.budget) + 1 -- strictly under, to break the tie
            local newStat = math.max(0, stat - over)
            if newStat ~= stat then
                edits[#edits + 1] = {
                    id = site.id, path = charPath(site.id), stat = statName,
                    from = stat, to = newStat, prestige = site.prestige,
                    swing = ex.back.budget, refSwing = ex.reference.budget,
                }
            end
        end
    end
    table.sort(edits, function(a, b) return a.id < b.id end)
    return edits
end

-- ---------------------------------------------------------------------------
-- Pass 4 -- the harmless mirror
-- ---------------------------------------------------------------------------

function M.walkMirror()
    local edits = {}
    for _, site in ipairs(bodySites()) do
        local row = Balance.measure(site.prestige, site.id, site.role,
            { sponsorDone = site.sponsorDone })
        local ex = row.ex

        -- REVIEW THIS PASS'S OUTPUT, never apply it blind. Low damage is very often authored intent
        -- in this game: walls, objects, support units and conjured constructs all say so in their
        -- blueprint headers ("feeble on purpose: she does not kill"). The first run of this pass
        -- proposed arming a scarecrow. Balance.isNonCombatant filters the bodies that declare
        -- themselves; the rest need a human to agree.
        if ex.back.floored and not Balance.isNonCombatant(site.id) then
            local def = Character.defs[site.id]
            local magical = false
            for _, t in ipairs(ex.backTags or {}) do
                if t == "magical" then magical = true end
            end
            local statName = magical and "magicDamage" or "damage"
            local stat = (def.stats and def.stats[statName]) or 0

            -- Enough to land a real blow on the reference: its mitigation plus a couple of points, so
            -- the body is a threat rather than a formality. Never raised past the reference's own
            -- swing, which is pass 3's ceiling -- the two passes must not fight each other.
            local want = ex.reference.mitigation + 2
            local newStat = stat + math.max(0, want - ex.back.budget)
            local ceiling = stat + math.max(0, ex.reference.budget - ex.back.budget)
            newStat = math.min(newStat, ceiling)

            if newStat > stat then
                edits[#edits + 1] = {
                    id = site.id, path = charPath(site.id), stat = statName,
                    from = stat, to = newStat, prestige = site.prestige,
                    swing = ex.back.budget, refMit = ex.reference.mitigation,
                }
            end
        end
    end
    table.sort(edits, function(a, b) return a.id < b.id end)
    return edits
end

-- ---------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------

local function applyArmor(edits, apply)
    local done, failed = 0, {}
    for _, e in ipairs(edits) do
        local text = e.path and readFile(e.path)
        if not text then
            failed[#failed + 1] = e.id .. " (no source file)"
        else
            local ok = true
            if e.ramp then
                local out = rewriteRamp(text, e.ramp.field, e.ramp.base, e.ramp.top)
                if out then text = out else ok = false end
            end
            if ok and e.flat then
                local out = rewriteStat(text, e.flat.field, e.flat.value)
                if out then text = out else ok = false end
            end
            if ok and e.resists then
                for _, r in ipairs(e.resists) do
                    local out = rewriteResist(text, r.tag, r.value)
                    if out then text = out else ok = false end
                end
            end
            if ok then
                if apply then writeFile(e.path, text) end
                done = done + 1
            else
                failed[#failed + 1] = e.id .. " (pattern did not match)"
            end
        end
    end
    return done, failed
end

-- A blueprint that builds its stats from another one (`bout.stats = {}` copying `base.stats`, see
-- data/characters/character_saber_bout.lua) has no literal to rewrite, and rewriting its BASE would
-- silently retune a different character. Those are reported as skipped-with-a-reason rather than as
-- failures: the fix is to tune the base, and the tool cannot know whether that is wanted.
local function isDerived(text)
    return text:find("%.stats%s*=%s*{%s*}") ~= nil
end

local function applyStatEdits(edits, apply)
    local done, failed = 0, {}
    for _, e in ipairs(edits) do
        local text = e.path and readFile(e.path)
        local fields = e.fields or { { stat = e.stat, from = e.from, to = e.to } }
        if not text then
            failed[#failed + 1] = e.id .. " (no source file)"
        else
            -- TRY THE REWRITE FIRST, and only blame derivation when it actually fails. A derived
            -- blueprint may still override the very stat being changed -- character_saber_bout copies
            -- its base's stats and then writes `bout.stats.health = 110` -- and refusing on the shape
            -- of the file rather than on the outcome skipped an edit that was perfectly available.
            local ok = true
            for _, f in ipairs(fields) do
                local out = rewriteStat(text, f.stat, f.to)
                if out then text = out else ok = false end
            end
            if ok then
                if apply then writeFile(e.path, text) end
                done = done + 1
            elseif isDerived(text) then
                failed[#failed + 1] = e.id .. " (derived blueprint -- tune its base instead)"
            else
                failed[#failed + 1] = e.id .. " (pattern did not match)"
            end
        end
    end
    return done, failed
end

local function report(label, count, failed)
    print(string.format("  %-28s %3d edit%s%s", label, count, count == 1 and "" or "s",
        #failed > 0 and ("   " .. #failed .. " UNMATCHED") or ""))
    for _, f in ipairs(failed) do print("      ! " .. f) end
end

M.PASSES = {
    { n = 1, label = "1 armour share", walk = function() return M.walkArmor() end, apply = applyArmor },
    { n = 2, label = "2 toughness", walk = function() return M.walkToughness() end, apply = applyStatEdits },
    { n = 3, label = "3 attack cap", walk = function() return M.walkAttack() end, apply = applyStatEdits },
    { n = 4, label = "4 harmless mirror", walk = function() return M.walkMirror() end, apply = applyStatEdits },
}

-- Print what a pass would do, one line per blueprint, so a dry run is reviewable rather than a count.
local function detail(n, edits)
    for _, e in ipairs(edits) do
        if n == 1 then
            local bits = {}
            if e.ramp then
                bits[#bits + 1] = string.format("%s ramp -> (%d, %d)", e.ramp.field, e.ramp.base, e.ramp.top)
            end
            if e.flat then bits[#bits + 1] = string.format("%s -> %d", e.flat.field, e.flat.value) end
            for _, r in ipairs(e.resists or {}) do
                bits[#bits + 1] = string.format("%s resist -> %d", r.tag, r.value)
            end
            print(string.format("      %-38s takes %d off a %.1f cap:  %s",
                e.id, e.total, e.cap, table.concat(bits, ", ")))
        else
            local bits = {}
            for _, f in ipairs(e.fields or { { stat = e.stat, from = e.from, to = e.to } }) do
                bits[#bits + 1] = string.format("%s %d -> %d", f.stat, f.from, f.to)
            end
            print(string.format("      %-38s %-34s %s", e.id, table.concat(bits, ", "), e.was or ""))
        end
    end
end

function M.run(args)
    local apply, only = false, nil
    for _, a in ipairs(args or {}) do
        if a == "apply" then apply = true end
        if tonumber(a) then only = tonumber(a) end
    end

    print("")
    print("Balance rescale -- bringing the two scales into the same unit")
    print(apply and "  APPLYING -- blueprints will be rewritten."
        or "  DRY RUN -- nothing is written. Pass `apply` to commit.")

    -- ONE PASS PER INVOCATION when applying. Each pass is measured against the state the one before
    -- it left, and the data model is loaded once at startup -- so applying two passes in a single run
    -- would measure the second against blueprints that are already stale on disk. `balance-rescale
    -- apply 1`, then 2, then 3, then 4, re-running `balance-report` in between.
    if apply and not only then
        print("")
        print("  Refusing to apply every pass at once: each is measured against the previous one's")
        print("  result, and the data model is only loaded at startup. Run them in order:")
        print("      balance-rescale apply 1   (armour -- must be first)")
        print("      balance-rescale apply 2   (innate defense)")
        print("      balance-rescale apply 3   (attack cap)")
        print("      balance-rescale apply 4   (harmless mirror)")
        print("")
        return
    end

    print("")
    for _, pass in ipairs(M.PASSES) do
        if not only or only == pass.n then
            local edits = pass.walk()
            local done, failed = pass.apply(edits, apply)
            report(pass.label, done, failed)
            detail(pass.n, edits)
        end
    end

    if not apply then
        print("")
        print("  Passes 2-4 are measured against the CURRENT armour, so their numbers move once")
        print("  pass 1 lands. Apply in order, re-running `balance-report` between each.")
    end
    print("")
end

return M
