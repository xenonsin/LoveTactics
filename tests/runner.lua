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

-- `pattern` (optional) narrows the run to specs whose module name CONTAINS it:
-- `test balance` runs tests.balance_spec, `test combat` runs tests.combat_spec and
-- tests.combat_fx_spec. A plain substring find, not a Lua pattern -- a spec name is full of
-- `_` and `-`, which a pattern would quietly reinterpret, and nobody writing `test item-`
-- means a character class.
--
-- It exists because the suite is 170-odd files and several are 80KB+; a data pass that has to
-- fix up fixtures re-runs the whole thing for every edit otherwise. The summary always names
-- the filter, so a green run over three specs can never be misread as a green run over all of
-- them.
function Runner.run(pattern)
    local passed, failed, ran = 0, 0, 0

    for _, specName in ipairs(discoverSpecs()) do
        if not pattern or specName:find(pattern, 1, true) then
            ran = ran + 1
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
    end

    if pattern then
        print(string.format("\n%d passed, %d failed  (%d spec%s matching '%s')",
            passed, failed, ran, ran == 1 and "" or "s", pattern))
        -- A filter that matched nothing is not a pass. Say so and fail, or a typo in the
        -- pattern reads as a clean suite.
        if ran == 0 then
            print("  no spec matched -- nothing ran")
            return false
        end
    else
        print(string.format("\n%d passed, %d failed", passed, failed))
    end
    return failed == 0
end

return Runner
