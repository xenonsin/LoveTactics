-- Curve widening: brings every tuned magnitude in data/items/**.lua under the one rule the forge
-- ladder needs, which is that a level you PAY for is a level that MOVES.
--
--   & "E:\LOVE\lovec.exe" . curve-widen              dry run -- every row, its verdict, a summary
--   & "E:\LOVE\lovec.exe" . curve-widen apply        rewrite the blueprints in place
--   & "E:\LOVE\lovec.exe" . curve-widen dead         list items that still buy nothing at some level
--
-- The defect it fixes: a magnitude authored as "6 at +0, 14 at +10" has eight points of climb to
-- spread over ten forge levels, so two of those levels are FLAT -- the ladder printed 8, 8 and 12, 12,
-- and the vendor charged 60g for the rung that changed nothing. 248 of 360 upgradable items had at
-- least one such rung. Widening the top to base + MAX_LEVEL makes the headline gain exactly one point
-- per level, so no rung is ever dead.
--
-- Which of the two a row gets is decided by the STAT, not by whether it happens to lead the tooltip
-- (see plan()): the blueprints pair their axes deliberately -- the Bloodlock's Defense and Magic
-- Defense "move together: the brace is whole-body", a horn's air grows longer AND stronger -- and a
-- rule that widened only the headline would have split every one of those pairs down the middle.
--
--   WIDEN -- a magnitude in SCALES: the numbers that sit on the damage/health scale and are what a
--            forge actually sells. Rewritten as Curve.ramp(base, max(top, base + Item.MAX_LEVEL)), so
--            an already-conforming curve (the reference Iron Sword's ramp(6, 16)) is left exactly as
--            it was tuned.
--   FLAT  -- everything else. A resist that climbs 1 -> 4 across the whole forge cannot step every
--            level no matter where its top sits, and inflating it to 1 -> 11 would stack a second full
--            mitigation curve on top of the widened defense it already rides beside. So it stops being
--            a curve and becomes the plain number it was at +0 -- the item's identity rather than its
--            growth, which is also how models/item.lua's Item.growth has always split them (`flat`).
--
-- Deliberately untouched:
--   * `activeAbility.aoe.*` -- a footprint that opens from a line into a cone is geometry, not a
--     magnitude, and a level that widens it is not a dead level (see Item.growth's `footprint`).
--   * every row of an item with NOTHING in SCALES -- a ward's `hits` counts blows swallowed and a
--     boot's `movement` counts tiles, so ramp(1, 11) is not a stronger ward or a faster boot, it is a
--     broken one. Flattening instead would take away the only growth those items have, so they keep
--     their authored step curve -- spelled out as a literal list, because models/curve.lua now refuses
--     a span that short. Eight items, named in tests/curve_spec.lua as the shapes the rule excuses.
--
-- Rewrites SOURCE TEXT (io.open on absolute paths, exactly as tools/curve_migrate), matching each row
-- by its key AND its numbers, and refuses to write a file it cannot parse afterwards. A row whose
-- pattern matches other than exactly once is reported for a hand edit rather than guessed at.

local Item = require("models.item")
local Curve = require("models.curve")

local M = {}

-- Mirrors the containers models/item.lua's eachMagnitude walks (tools/curve_migrate's list).
local CONTAINERS = { "activeAbility", "bonus", "resist", "maxBonus", "unarmedBonus", "waitBehavior",
                     "incense", "aura" }

-- The magnitudes a forge may sell a point of per level, as "container.key". Everything numeric that is
-- NOT here is identity, not growth, and goes flat: the counted-in-whole-steps stats (a ward's `hits`, a
-- boot's `movement`, a censer's `radius`, a horn's `earshot`, an aura's reach), the tempo fields, the
-- percentages -- and every `resist`, which is a second mitigation curve riding beside a defense that is
-- already being widened.
local SCALES = {
    ["activeAbility.damage"] = true, ["activeAbility.healing"] = true,
    ["activeAbility.restore"] = true, ["activeAbility.reviveHealth"] = true,
    ["activeAbility.stun"] = true,
    ["bonus.defense"] = true, ["bonus.magicDefense"] = true,
    ["bonus.damage"] = true, ["bonus.magicDamage"] = true,
    -- A resource granted as a flat bonus or as a raised ceiling is the same scale either way (the Maw
    -- of the Unfed hands out health through `bonus`, the reliquaries through `maxBonus`).
    ["bonus.health"] = true, ["bonus.mana"] = true, ["bonus.stamina"] = true,
    ["maxBonus.health"] = true, ["maxBonus.mana"] = true, ["maxBonus.stamina"] = true,
    -- `drunkDamage` is the Drunken Fist's damage, paid out under a condition rather than a different
    -- scale.
    ["unarmedBonus.damage"] = true, ["unarmedBonus.drunkDamage"] = true,
    -- What a swapped Wait pays out (models/item.lua's WAIT_BEHAVIOR_MAGNITUDES, minus `covers`, which
    -- counts bodies): a forged shield braces harder, a forged staff meditates deeper, a forged horn
    -- holds its air longer and pours more into it.
    ["waitBehavior.defense"] = true, ["waitBehavior.power"] = true, ["waitBehavior.mana"] = true,
    ["waitBehavior.stamina"] = true, ["waitBehavior.amount"] = true, ["waitBehavior.duration"] = true,
    -- A censer's smoke thickens with its level, and an aura's payload with it -- both arrive as a
    -- status's magnitude, which is the damage/defense scale wearing a different name.
    ["incense.amount"] = true,
    ["aura.amountBonus"] = true, ["aura.status.opts.magnitude"] = true,
}

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do if type(k) == "string" then keys[#keys + 1] = k end end
    table.sort(keys)
    return keys
end

-- Is this a per-level row -- a list of exactly LEVELS numbers?
local function isRow(v)
    if type(v) ~= "table" or #v ~= Curve.LEVELS then return false end
    for i = 1, Curve.LEVELS do
        if type(v[i]) ~= "number" then return false end
    end
    return true
end

local function eachRow(def, fn)
    local function walk(t, path)
        for _, k in ipairs(sortedKeys(t)) do
            local v = t[k]
            local here = path .. "." .. k
            if isRow(v) then fn(here, v, k) elseif type(v) == "table" then walk(v, here) end
        end
    end
    for _, name in ipairs(CONTAINERS) do
        if type(def[name]) == "table" then walk(def[name], name) end
    end
end

-- Does this row climb at all? Eleven identical numbers are not a growth axis -- `damage = Curve.ramp(0)`
-- on the Shepherd's Crook, which deals nothing by design -- so such a row is a flat magnitude that has
-- been wearing a curve's clothes, and flattening it is also what stops the forge from offering to raise
-- it (see Item.isUpgradable).
local function climbs(values)
    return values[Curve.LEVELS] > values[1]
end

-- Moving in EITHER direction still counts as growth: Quickened Sigil's tempo bonus deepens from -1 to
-- -4, which is the item's whole forge path even though the number gets smaller. Only widening insists on
-- a climb -- a discount that deepened by a point per level would have to reach -10.
local function moves(values)
    return values[Curve.LEVELS] ~= values[1]
end

-- A straight line from base to top, computed here rather than called: models/curve.lua has since learned
-- to refuse the short spans this tool exists to find, and it should still be able to recognise one.
local function rampOf(base, top)
    local step, out = (top - base) / (Curve.LEVELS - 1), {}
    for i = 1, Curve.LEVELS do
        local x = base + (i - 1) * step
        out[i] = (x < 0) and -math.floor(-x + 0.5) or math.floor(x + 0.5)
    end
    return out
end

-- Is this row ALREADY what the rule asks for -- a ramp whose climb covers every forge level? Then it is
-- left exactly as it was tuned, whatever stat it sits on: the Sceptic's Harness spans its status resist
-- 8 -> 18 by hand, and a sweep that flattened a curve for not being on a list would be throwing away
-- the very shape it is trying to spread.
local function compliant(values)
    local base, top = values[1], values[Curve.LEVELS]
    if top - base < Item.MAX_LEVEL then return false end
    local ramp = rampOf(base, top)
    for i = 1, Curve.LEVELS do if ramp[i] ~= values[i] then return false end end
    return true
end

-- One item's verdicts, as { [path] = "widen" | "flat" | "keep" } plus the new top for each widen. Two
-- passes, because the second question depends on the answer to the first: does this item have any
-- growth axis at all, and if it does not, its step curves are all it has.
local function plan(def)
    local rows, scaling = {}, false
    eachRow(def, function(path, values)
        rows[#rows + 1] = { path = path, values = values }
        -- An axis the forge can actually sell a point of per level.
        if compliant(values) or (SCALES[path] and climbs(values)) then scaling = true end
    end)
    local out = {}
    for _, row in ipairs(rows) do
        local base, top = row.values[1], row.values[Curve.LEVELS]
        if row.path:find("^activeAbility%.aoe%.") then
            out[row.path] = { verdict = "keep" }
        elseif compliant(row.values) then
            -- Already a ramp that moves every level: the widen branch below recognises it as a no-op.
            out[row.path] = { verdict = "widen", top = top }
        elseif SCALES[row.path] and climbs(row.values) then
            out[row.path] = { verdict = "widen", top = math.max(top, base + Item.MAX_LEVEL) }
        elseif not moves(row.values) then
            -- Nothing to preserve in eleven identical numbers, whatever else the item does.
            out[row.path] = { verdict = "flat" }
        elseif scaling then
            out[row.path] = { verdict = "flat" }
        else
            -- Nothing on this item scales, so this step curve IS its forge path. Kept as authored.
            out[row.path] = { verdict = "keep" }
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Source rewriting
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
    local ok, err = loadstring(text)
    assert(ok, "refusing to write invalid Lua to " .. rel .. ": " .. tostring(err))
    local f = assert(io.open(sourcePath(rel), "wb"))
    f:write(text)
    f:close()
end

local function esc(s)
    return (tostring(s):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Every way this row can be spelled in source, as Lua patterns: the two generator calls (with the top
-- dropped when it is simply twice the base, which is what the one-argument form means) and the literal
-- eleven-number list. Each is anchored to the row's own KEY, because two rows in one file can carry
-- identical numbers and want different verdicts (a shield's `bonus.defense` widens where its
-- `waitBehavior.defense` goes flat).
local function spellings(key, values, generatorsOnly)
    local base, top = values[1], values[Curve.LEVELS]
    local out = {}
    local head = esc(key) .. "%s*=%s*"
    -- The generators as they were BEFORE this sweep: models/curve.lua has since dropped `paired` and
    -- learned to refuse a curve this short, so both are reproduced locally rather than called.
    local styles = {
        ramp = function(level) return level end,
        paired = function(level) return 2 * math.floor(level / 2) end,
    }
    for _, style in ipairs({ "ramp", "paired" }) do
        local step, same = (top - base) / (Curve.LEVELS - 1), true
        for i = 1, Curve.LEVELS do
            local x = base + styles[style](i - 1) * step
            local r = (x < 0) and -math.floor(-x + 0.5) or math.floor(x + 0.5)
            if r ~= values[i] then same = false break end
        end
        if same then
            out[#out + 1] = head .. "Curve%." .. style .. "%(%s*" .. esc(base) .. "%s*,%s*" .. esc(top) .. "%s*%)"
            if top == base * 2 then
                out[#out + 1] = head .. "Curve%." .. style .. "%(%s*" .. esc(base) .. "%s*%)"
            end
        end
    end
    if generatorsOnly then return out end
    local parts = {}
    for i = 1, Curve.LEVELS do parts[#parts + 1] = esc(values[i]) end
    out[#out + 1] = head .. "%{%s*" .. table.concat(parts, "%s*,%s*") .. "%s*,?%s*%}"
    return out
end

-- Swap one row's authored text for `replacement`. Returns the new text, or nil + how many matches it
-- found (0 = an unusual spelling, >1 = ambiguous), so an uncertain row is reported, never guessed.
local function rewriteRow(text, key, values, replacement, generatorsOnly)
    for _, pat in ipairs(spellings(key, values, generatorsOnly)) do
        local _, n = text:gsub(pat, "")
        if n == 1 then
            return (text:gsub(pat, (key .. " = " .. replacement):gsub("%%", "%%%%"), 1))
        elseif n > 1 then
            return nil, n
        end
    end
    return nil, 0
end

-- Drop the now-unused require line from a file whose last curve just went flat, and the level ruler a
-- hand-typed row left behind. Keeps a flattened blueprint from carrying a dead dependency.
-- The line ending this file already uses, for the two edits below that splice a whole line.
local function newlineOf(text)
    return text:find("\r\n") and "\r\n" or "\n"
end

-- A blueprint whose rows were all hand-typed literals has never needed models/curve.lua; widening one
-- into a generator call is the moment it does. Mirrors tools/curve_migrate's ensureRequire, including
-- the few blueprints that open with `return {` on line 1 rather than a header comment.
local REQUIRE_LINE = 'local Curve = require("models.curve")'
local function ensureRequire(text)
    if text:find("models%.curve") then return text end
    local nl = newlineOf(text)
    local inserted = (REQUIRE_LINE .. nl .. nl .. "return {"):gsub("%%", "%%%%")
    if text:find("^return%s*{") then
        return (text:gsub("^return%s*{", inserted, 1))
    end
    local out, n = text:gsub("\r?\nreturn%s*{", nl .. inserted, 1)
    if n == 0 then return nil end
    return out
end

-- Matched and replaced with the file's OWN line ending: the tree is checked out CRLF (core.autocrlf),
-- so splicing a bare "\n" in would leave the blueprint mixed -- invisible in a diff, and a needless
-- line-ending churn for the next person who touches it (tools/curve_migrate makes the same point).
local REQUIRE_PATTERN = '\r?\nlocal Curve = require%("models%.curve"%)\r?\n'
local function tidyRequire(text)
    if text:find("Curve%.") then return text end
    return (text:gsub(REQUIRE_PATTERN, newlineOf(text), 1))
end

local function itemFiles()
    local out = {}
    local function scan(dir)
        for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local path = dir .. "/" .. file
            local info = love.filesystem.getInfo(path)
            if info and info.type == "directory" then
                scan(path)
            else
                local id = file:match("^(.+)%.lua$")
                if id then out[#out + 1] = { id = id, rel = path } end
            end
        end
    end
    scan("data/items")
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- ---------------------------------------------------------------------------
-- Dead-level report: the property all of this exists to buy
-- ---------------------------------------------------------------------------

local function deadLevels(id)
    local g = Item.growth(id)
    if not g or #g.stats == 0 then return nil end
    local fp = {}
    if g.footprint then for _, lvl in ipairs(g.footprint.changedAt) do fp[lvl] = true end end
    local dead = {}
    for lvl = 1, g.maxLevel do
        local moved = fp[lvl] or false
        for _, s in ipairs(g.stats) do if s.changed[lvl] then moved = true end end
        if not moved then dead[#dead + 1] = lvl end
    end
    return dead
end

local function reportDead()
    local total, bad, offered = 0, 0, {}
    for _, it in ipairs(itemFiles()) do
        local dead = deadLevels(it.id)
        if dead then
            total = total + 1
            if #dead > 0 then
                bad = bad + 1
                print(string.format("  %-34s dead at %s", it.id, table.concat(dead, ",")))
            end
        -- No CHARTED stat, yet the bench still offers to forge it. For a `scalesWithLevel` item that is
        -- expected -- its gain is computed in the effect off fx.level, so there is no magnitude row for
        -- the ladder to draw -- and for anything else it is the whole-ladder version of a dead level,
        -- which is what Item.isUpgradable's "a stat that MOVES" now rules out.
        elseif Item.isUpgradable(Item.instantiate(it.id, 1, 0)) then
            local why = Item.defs[it.id].scalesWithLevel and " (scalesWithLevel: gain lives in the effect)" or ""
            offered[#offered + 1] = it.id .. why
        end
    end
    print("")
    print(string.format("%d upgradable items, %d with a level that buys nothing", total, bad))
    if #offered > 0 then
        print("")
        print("-- forgeable with nothing for the ladder to chart --")
        for _, id in ipairs(offered) do print("  " .. id) end
    end
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------

function M.run(args)
    args = args or {}
    local mode = args[1]
    if mode == "dead" then return reportDead() end

    local apply = (mode == "apply")
    local widened, flattened, kept, files, stuck = 0, 0, 0, 0, 0
    local keeps, flats, problems = {}, {}, {}

    for _, it in ipairs(itemFiles()) do
        local def = Item.defs[it.id]
        if def then
            local verdicts = plan(def)
            local rows = {}
            eachRow(def, function(path, values, key) rows[#rows + 1] = { path = path, key = key, values = values } end)
            if #rows > 0 then
                local text = readFile(it.rel)
                local changed = 0
                for _, row in ipairs(rows) do
                    local decided = verdicts[row.path]
                    local verdict, newTop = decided.verdict, decided.top
                    local replacement, generatorsOnly
                    if verdict == "widen" then
                        local base = row.values[1]
                        local call = (newTop == base * 2) and ("Curve.ramp(" .. base .. ")")
                            or ("Curve.ramp(" .. base .. ", " .. newTop .. ")")
                        -- Already exactly this? Then there is nothing to rewrite.
                        local cur = Curve.ramp(base, newTop)
                        local same = true
                        for i = 1, Curve.LEVELS do if cur[i] ~= row.values[i] then same = false break end end
                        if not same then replacement = call end
                        widened = widened + 1
                    elseif verdict == "flat" then
                        replacement = tostring(row.values[1])
                        flattened = flattened + 1
                        flats[#flats + 1] = string.format("%-34s %-30s {%s} -> %s", it.id, row.path,
                            table.concat(row.values, ","), replacement)
                    else
                        kept = kept + 1
                        keeps[#keeps + 1] = string.format("%-34s %-30s {%s}", it.id, row.path,
                            table.concat(row.values, ","))
                        -- Kept, but no longer spelled as a generator: models/curve.lua now refuses a
                        -- span this short, so a row that survives on its own terms has to say its
                        -- eleven numbers out loud. That IS the escape hatch -- and it makes the
                        -- exception visible to the next reader instead of hiding it in a call that
                        -- looks like every other curve.
                        replacement = "{ " .. table.concat(row.values, ", ") .. " }"
                        generatorsOnly = true
                    end
                    if replacement and text then
                        local out, n = rewriteRow(text, row.key, row.values, replacement, generatorsOnly)
                        if out then
                            text = out
                            changed = changed + 1
                        elseif generatorsOnly and n == 0 then
                            -- A kept row that was already a literal list: nothing to say out loud.
                        else
                            stuck = stuck + 1
                            problems[#problems + 1] = string.format("%-34s %-30s %d matches -> %s",
                                it.id, row.path, n or 0, replacement)
                        end
                    end
                end
                if changed > 0 and text then
                    -- One of these is always a no-op: a file that gained a generator call needs the
                    -- require, a file whose last one just went flat no longer does.
                    local out = tidyRequire(text)
                    if out:find("Curve%.") then out = ensureRequire(out) end
                    if not out then
                        stuck = stuck + 1
                        problems[#problems + 1] = it.id .. "  no `return {` to hang the require on"
                    else
                        files = files + 1
                        if apply then writeFile(it.rel, out) end
                    end
                end
            end
        end
    end

    print("")
    print((apply and "rewrote " or "would rewrite ") .. files .. " files: "
        .. widened .. " headline rows widened, " .. flattened .. " secondary rows flattened, "
        .. kept .. " left alone")
    if #keeps > 0 then
        print("")
        print("-- left alone (footprints, and the step curves that are an item's only growth) --")
        for _, l in ipairs(keeps) do print("  " .. l) end
    end
    if not apply and #flats > 0 then
        print("")
        print("-- flattened (identity, not growth) --")
        for _, l in ipairs(flats) do print("  " .. l) end
    end
    if stuck > 0 then
        print("")
        print("-- NOT REWRITTEN, needs a hand edit --")
        for _, l in ipairs(problems) do print("  " .. l) end
    end
    if not apply then
        print("")
        print("re-run with `apply` to write the changes")
    end
end

return M
