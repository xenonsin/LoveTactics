-- Tests for player preferences (models/settings.lua): the per-install options behind the settings
-- screen. What matters is that a preference reads as its default until something says otherwise,
-- that a stale or hand-mangled file degrades to defaults instead of poisoning the game, and that
-- `set` stays in memory -- the whole reason a test can run at all without rewriting the player's
-- own settings file.
--
-- The screen itself (states/settings.lua) is covered by the in-game verification pass.

local Settings = require("models.settings")

-- Run `fn` with the in-memory values restored afterwards, so one case can never decide the next.
-- Nothing here writes, so there is no file to put back.
local function sandboxed(fn)
    local saved = {}
    for _, def in ipairs(Settings.defs) do saved[def.key] = Settings.get(def.key) end
    local ok, err = pcall(fn)
    for key, value in pairs(saved) do Settings.set(key, value) end
    assert(ok, err)
end

return {
    {
        name = "every option declares a name, a description and a typed default",
        fn = function()
            assert(#Settings.defs > 0, "there are no options at all")
            local seen = {}
            for _, def in ipairs(Settings.defs) do
                assert(def.key and def.key ~= "", "an option has no key")
                assert(not seen[def.key], "two options share the key " .. tostring(def.key))
                seen[def.key] = true
                assert(def.name and def.name ~= "", def.key .. " has no name")
                assert(def.description and def.description ~= "", def.key .. " has no description")
                assert(def.default ~= nil, def.key .. " has no default")
                local t = type(def.default)
                assert(t == "boolean" or t == "number" or t == "string",
                    def.key .. " defaults to a " .. t .. ", which settings cannot serialize")
                assert(def.kind == "toggle" or def.kind == "range",
                    def.key .. " has an unknown kind: " .. tostring(def.kind))

                -- Each kind carries what its row needs to render and work. states/settings.lua reads
                -- these without checking, so a half-declared option is a crash in the options screen.
                if def.kind == "toggle" then
                    assert(t == "boolean", def.key .. " is a toggle but does not default to a boolean")
                else
                    assert(t == "number", def.key .. " is a range but does not default to a number")
                    assert(type(def.min) == "number" and type(def.max) == "number",
                        def.key .. " is a range with no bounds")
                    assert(def.min < def.max, def.key .. " has inverted bounds")
                    assert(type(def.step) == "number" and def.step > 0,
                        def.key .. " has no usable step")
                    assert(def.default >= def.min and def.default <= def.max,
                        def.key .. " defaults outside its own bounds")
                end
            end
        end,
    },
    {
        name = "an unset option reads as its default",
        fn = function()
            sandboxed(function()
                for _, def in ipairs(Settings.defs) do
                    Settings.set(def.key, nil)
                    assert(Settings.get(def.key) == def.default,
                        def.key .. " did not fall back to its default")
                end
            end)
        end,
    },
    {
        name = "the low-health vignette is off until asked for",
        fn = function()
            -- The one option that ships OFF. states/battle.lua's updateDangerVignette gates on it,
            -- and it gates on `~= true` -- so a default that drifted to `true`, or a key renamed out
            -- from under that call site, would quietly put the red edge back on every player's board.
            local def
            for _, d in ipairs(Settings.defs) do
                if d.key == "danger_vignette" then def = d end
            end
            assert(def, "the danger_vignette option is gone from Settings.defs")
            assert(def.default == false, "the low-health vignette must default to off")
        end,
    },
    {
        name = "an unknown key is nil rather than an error",
        fn = function()
            -- Every call site gates on the value, so a key removed from defs between builds has to
            -- read as "off" rather than throwing from inside a draw.
            assert(Settings.get("no_such_option") == nil, "an unknown key returned something")
        end,
    },
    {
        name = "toggle flips the default on its first press",
        fn = function()
            sandboxed(function()
                -- The first TOGGLE, found rather than assumed: defs[1] is a volume range now, and a
                -- test that silently depends on the order options are listed in is a test that breaks
                -- every time somebody rearranges the settings screen.
                local def
                for _, d in ipairs(Settings.defs) do
                    if d.kind == "toggle" then def = d break end
                end
                assert(def, "there are no toggle options left to exercise")
                Settings.set(def.key, nil)
                assert(Settings.toggle(def.key) == not def.default,
                    "the first toggle did not turn the default over")
                assert(Settings.get(def.key) == not def.default, "the flip was not kept")
                Settings.toggle(def.key)
                assert(Settings.get(def.key) == def.default, "flipping back did not return the default")
            end)
        end,
    },
    {
        name = "set does not touch the file",
        fn = function()
            sandboxed(function()
                local before = love.filesystem.getInfo(Settings.FILE)
                local beforeSource = before and love.filesystem.read(Settings.FILE)
                for _, def in ipairs(Settings.defs) do Settings.set(def.key, not def.default) end
                local after = love.filesystem.getInfo(Settings.FILE)
                if before then
                    assert(after, "setting a preference deleted the settings file")
                    assert(love.filesystem.read(Settings.FILE) == beforeSource,
                        "Settings.set wrote to disk; only Settings.save may")
                else
                    assert(not after, "Settings.set created a settings file; only Settings.save may")
                end
            end)
        end,
    },
}
