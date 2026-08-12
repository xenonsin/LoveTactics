-- Day migration: run with
--
--     & "E:\LOVE\lovec.exe" . day-migrate [apply]
--
-- Rewrites the DIFFICULTY half of prestige onto the calendar, across the data layer. Dry run by
-- default; `apply` writes the files.
--
-- WHY A TOOL AND NOT A SWEEP. 99 blueprints carry `ctx.prestige` inside a composition function and 20
-- encounters carry a `minPrestige` gate. A hand pass over 119 files is a hand pass that misses four of
-- them, and the failure mode is silent -- a composition function reading a field nobody sets any more
-- gets `nil`, which in Lua is not an error until it is arithmetic, and `math.floor(nil / 2)` is a crash
-- on one quest at one prestige. This reports every file it touches and counts them, so the number in
-- the commit message is one somebody can regenerate.
--
-- WHAT MOVES, AND WHAT DELIBERATELY DOES NOT. Prestige was one number doing two jobs
-- (models/calendar.lua):
--
--     the difficulty dial  -> THE DAY. Head-count formulas, encounter gating, loot band, enemy level.
--                             That is this tool.
--     campaign standing    -> QUESTS COMPLETED. Building unlocks, `requiredPrestige` on quests, the
--                             conversation predicate. A separate pass, because it is a separate
--                             question and its off-by-one is different (prestige started at 1 and rose
--                             by 1 a quest, so a gate of 3 meant two quests done).
--
-- So this tool touches `ctx.prestige` and `minPrestige` and leaves `requiredPrestige` and
-- `unlockPrestige` exactly where they are. A file carrying both is normal and is rewritten in part.
--
-- The rename is intentionally NOT `ctx.danger`. A composition function asks "how far into the campaign
-- is this", which is the day; the enemy LEVEL it implies is Calendar.dangerLevel's business and is
-- resolved by the caller, not in ninety-nine data files.

local M = {}

-- Every substitution, as { pattern, replacement, what }. Lua patterns, so `%.` is a literal dot.
-- Ordered: the longest, most specific first, so a shorter rule cannot eat part of a longer match.
local RULES = {
    { "ctx%.prestige", "ctx.day", "ctx.prestige -> ctx.day" },
    { "minPrestige", "minDay", "minPrestige -> minDay" },
}

-- The directories a blueprint can live in. Walked explicitly rather than globbing the whole project:
-- models/ and states/ read these fields too, but each of those call sites needs a judgement about
-- whether it wants the day or the level the day implies, and a blind rename would make that decision
-- silently and wrongly.
local DIRS = {
    "data/quests", "data/encounters", "data/relics", "data/arenas",
    "data/characters", "data/conversations", "data/meals", "data/biomes",
}

local function eachFile(dir, fn)
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir .. "/" .. name
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" then
            eachFile(path, fn)
        elseif name:sub(-4) == ".lua" then
            fn(path)
        end
    end
end

function M.run(args)
    args = args or {}
    local apply = false
    for _, a in ipairs(args) do if a == "apply" then apply = true end end

    local touched, hits, byRule = {}, 0, {}
    for _, rule in ipairs(RULES) do byRule[rule[3]] = 0 end

    for _, dir in ipairs(DIRS) do
        if love.filesystem.getInfo(dir) then
            eachFile(dir, function(path)
                local src = love.filesystem.read(path)
                if not src then return end
                local out, fileHits = src, 0
                for _, rule in ipairs(RULES) do
                    local n
                    out, n = out:gsub(rule[1], rule[2])
                    if n > 0 then
                        fileHits = fileHits + n
                        byRule[rule[3]] = byRule[rule[3]] + n
                    end
                end
                if fileHits > 0 then
                    touched[#touched + 1] = { path = path, hits = fileHits, body = out }
                    hits = hits + fileHits
                end
            end)
        end
    end

    table.sort(touched, function(a, b) return a.path < b.path end)

    print(string.format("DAY MIGRATION -- %s", apply and "APPLYING" or "dry run (pass `apply` to write)"))
    print("")
    for _, rule in ipairs(RULES) do
        print(string.format("  %-28s %5d", rule[3], byRule[rule[3]]))
    end
    print(string.format("  %-28s %5d in %d files", "total", hits, #touched))
    print("")

    if not apply then
        for _, t in ipairs(touched) do
            print(string.format("    %-62s %2d", t.path, t.hits))
        end
        print("")
        print("  Nothing written. Re-run with `apply`.")
        return
    end

    -- love.filesystem writes to the SAVE directory, not the project, so the write goes through io.
    -- Same route tools/unlock_rescale.lua takes for the same reason.
    local written, failed = 0, {}
    for _, t in ipairs(touched) do
        local fh = io.open(t.path, "wb")
        if fh then
            fh:write(t.body)
            fh:close()
            written = written + 1
        else
            failed[#failed + 1] = t.path
        end
    end
    print(string.format("  wrote %d files", written))
    for _, p in ipairs(failed) do print("  COULD NOT WRITE: " .. p) end
end

return M
