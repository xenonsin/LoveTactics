-- Every UI module must be REQUIRE-able with no window: fonts, images and canvases belong in
-- :new()/:draw(), never at require-time (see CLAUDE.md). The headless suite runs with
-- `t.window = false`, so love.graphics.newFont would throw here -- which is exactly the point.
-- Requiring each module also catches a syntax error or a bad require path in a file the model
-- specs never touch.

local function eachUiModule(visit)
    local function walk(dir, prefix)
        for _, entry in ipairs(love.filesystem.getDirectoryItems(dir)) do
            local path = dir .. "/" .. entry
            if love.filesystem.getInfo(path).type == "directory" then
                walk(path, prefix .. entry .. ".")
            elseif entry:sub(-4) == ".lua" then
                visit(prefix .. entry:sub(1, -5))
            end
        end
    end
    walk("ui", "ui.")
end

return {
    {
        name = "every ui module loads headlessly (no love.graphics at require-time)",
        fn = function()
            local count = 0
            eachUiModule(function(module)
                local ok, err = pcall(require, module)
                assert(ok, module .. " failed to load: " .. tostring(err))
                count = count + 1
            end)
            assert(count > 0, "no ui modules were found to check")
        end,
    },
}
