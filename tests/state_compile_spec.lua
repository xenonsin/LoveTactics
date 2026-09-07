-- DOES THE SCREEN STILL COMPILE.
--
-- Every other spec in this suite loads a model. Not one of them loads a state or a panel, which means a
-- green run has never said anything at all about whether the game opens -- a syntax error in
-- states/game.lua, or one local past Lua 5.1's 200-per-function ceiling in states/battle.lua, is a
-- suite that passes and a game that dies on launch.
--
-- COMPILED, NOT RUN. Executing a state module would draw it into fonts, images and sound at require
-- time, which is a different (and much noisier) test. What this catches is the class of failure that
-- has actually bitten: a malformed chunk, and the local ceiling -- which is a COMPILE error naming an
-- unrelated line six hundred lines away, so it is exactly the kind of thing that is cheap to catch here
-- and expensive to diagnose anywhere else.
--
-- It does NOT catch a call to a forward-declared local made above its `local` line: that compiles
-- cleanly and resolves to a nil global at runtime. Nothing here can catch that; the real window is what
-- catches that.

local function chunksIn(dir)
    local out = {}
    for _, name in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir .. "/" .. name
        if love.filesystem.getInfo(path).type == "directory" then
            for _, deeper in ipairs(chunksIn(path)) do out[#out + 1] = deeper end
        elseif name:match("%.lua$") then
            out[#out + 1] = path
        end
    end
    return out
end

local function compileAll(dir)
    local checked = 0
    for _, path in ipairs(chunksIn(dir)) do
        local chunk, err = love.filesystem.load(path)
        assert(chunk, path .. " does not compile: " .. tostring(err))
        checked = checked + 1
    end
    assert(checked > 0, "no Lua files found under " .. dir .. " -- the check is testing nothing")
    return checked
end

return {
    {
        name = "every screen compiles",
        fn = function() compileAll("states") end,
    },
    {
        name = "every widget and pop-up panel compiles",
        fn = function() compileAll("ui") end,
    },
    {
        name = "every model compiles",
        fn = function() compileAll("models") end,
    },
    {
        name = "main.lua and the scaler compile",
        fn = function()
            for _, path in ipairs({ "main.lua", "scale.lua", "conf.lua" }) do
                if love.filesystem.getInfo(path) then
                    local chunk, err = love.filesystem.load(path)
                    assert(chunk, path .. " does not compile: " .. tostring(err))
                end
            end
        end,
    },
    {
        -- A UTF-8 byte-order mark is the one malformation the compile check above cannot see: LuaJIT
        -- skips it, so the desktop game and this whole suite run happily, while the web build --
        -- love.js is plain Lua 5.1, which has no such tolerance -- dies at require time with
        -- "unexpected symbol near '<mojibake>'". PowerShell's Set-Content -Encoding utf8 writes one
        -- by default, so any tool or hand-edit that goes through it can plant a crash that only the
        -- browser will ever report.
        name = "no Lua file opens with a byte-order mark",
        fn = function()
            local checked = 0
            for _, dir in ipairs({ "states", "ui", "models", "data", "tests", "tools" }) do
                for _, path in ipairs(chunksIn(dir)) do
                    local head = love.filesystem.read(path, 3)
                    assert(head ~= "\239\187\191",
                        path .. " starts with a UTF-8 BOM -- LuaJIT ignores it, love.js does not")
                    checked = checked + 1
                end
            end
            assert(checked > 0, "no Lua files found -- the check is testing nothing")
        end,
    },
}
