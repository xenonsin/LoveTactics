-- Minimal headless test runner. Every tests/*_spec.lua module is auto-scanned;
-- each returns a list of { name = "...", fn = function() ... end } cases, and a
-- case fails by raising (assert). Run with:  & "E:\LOVE\lovec.exe" . test
--
-- See main.lua / conf.lua for how the `test` argument is wired up.

local Runner = {}

-- Discover every spec module in tests/ (files ending in _spec.lua), sorted for
-- stable ordering. Drop in a new *_spec.lua and it runs automatically.
local function discoverSpecs()
    local specs = {}
    for _, file in ipairs(love.filesystem.getDirectoryItems("tests")) do
        local id = file:match("^(.+_spec)%.lua$")
        if id then
            specs[#specs + 1] = "tests." .. id
        end
    end
    table.sort(specs)
    return specs
end

function Runner.run()
    local passed, failed = 0, 0

    for _, specName in ipairs(discoverSpecs()) do
        for _, case in ipairs(require(specName)) do
            local ok, err = pcall(case.fn)
            if ok then
                passed = passed + 1
                print("  ok   - " .. case.name)
            else
                failed = failed + 1
                print("  FAIL - " .. case.name)
                print("         " .. tostring(err))
            end
        end
    end

    print(string.format("\n%d passed, %d failed", passed, failed))
    return failed == 0
end

return Runner
