-- Every state and pop-up panel must at least COMPILE.
--
-- This spec exists because of a gap that had been open the whole project: no test loads a state module.
-- states/battle.lua, states/game.lua and states/hub.lua are thousands of lines each and the suite could
-- go green with any of them syntactically broken -- the game would simply fail to open, and nothing
-- before launch would say so.
--
-- The specific failure it is here to catch: states/battle.lua sits within a couple of declarations of
-- Lua 5.1's **200 local variables per function** ceiling. Crossing it is a COMPILE error, and one whose
-- message names a line unrelated to the cause, so a change that trips it looks like a mystery rather
-- than a budget. This turns that into a named failure at test time.
--
-- WHAT THIS DOES NOT DO, stated plainly so nobody trusts it further than it goes: love.filesystem.load
-- compiles, it does not execute. A file that parses can still be wrong at runtime in ways this cannot
-- see -- most sharply, calling a forward-declared local from ABOVE its `local` line compiles fine and
-- silently resolves to a nil global. A green run here means "the screens will load", never "the screens
-- work". Driving the real 1280x720 window is still the only check for that.

local function luaFilesIn(dir)
    local out = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir .. "/" .. name
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" then
            for _, nested in ipairs(luaFilesIn(path)) do out[#out + 1] = nested end
        elseif name:sub(-4) == ".lua" then
            out[#out + 1] = path
        end
    end
    table.sort(out) -- getDirectoryItems order is unspecified; a failure should name the same file twice
    return out
end

local function compileAll(dir)
    local failures = {}
    local files = luaFilesIn(dir)
    for _, path in ipairs(files) do
        local chunk, err = love.filesystem.load(path)
        if not chunk then failures[#failures + 1] = path .. ": " .. tostring(err) end
    end
    return files, failures
end

local function case(label, dir)
    return { name = label, fn = function()
        local files, failures = compileAll(dir)
        assert(#files > 0, "found no Lua files under " .. dir .. " -- the walk is broken, not the code")
        assert(#failures == 0, #failures .. " file(s) under " .. dir ..
            " do not compile:\n  " .. table.concat(failures, "\n  "))
    end }
end

return {
    case("every screen in states/ compiles", "states"),
    case("every pop-up panel in ui/ compiles", "ui"),
    case("every model compiles", "models"),

    { name = "states/battle.lua is inside Lua 5.1's 200-local ceiling", fn = function()
        -- The canary, called out by name because it is the one file close enough to the limit that an
        -- ordinary edit can cross it. If this fails, the fix is never "delete a feature" -- it is to
        -- fold related file-scope locals into one table, which costs one indirection and buys back a
        -- dozen slots at a time.
        local chunk, err = love.filesystem.load("states/battle.lua")
        assert(chunk, "states/battle.lua does not compile: " .. tostring(err) ..
            "\n(if this mentions 'too many local variables', see the note above)")
    end },
}
