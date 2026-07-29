-- The audio layer: the tolerant loader, the cue table, and the volume arithmetic.
--
-- The property under test throughout is TOLERANCE. A cue whose file is absent -- the state every cue
-- was in before any audio landed, and the state a fresh clone with no assets/ is in -- must play
-- nothing rather than raise, log, or slow anything down. If these cases ever start failing, the
-- symptom in the game is not "no sound" -- it is a crash in a menu. The tolerance case exercises this
-- against a cue pointed at a file that genuinely does not exist, so it holds whether or not the
-- shipped cues have real audio behind them on this machine.
--
-- The suite runs with `t.window = false`, which drops the window but NOT love.audio, so these run
-- against the real module. That is exactly the environment a player is in.

local Sound = require("models.sound")
local Settings = require("models.settings")

-- Volume preferences are per-install and this suite must not leave the developer's own levels
-- rewritten, so every case that touches them restores the module afterwards. Settings.set is memory
-- only (Settings.save is what writes), so reload() is enough.
local function withVolumes(master, music, sfx, fn)
    Settings.set("volume_master", master)
    Settings.set("volume_music", music)
    Settings.set("volume_sfx", sfx)
    local ok, err = pcall(fn)
    Settings.reload()
    assert(ok, err)
end

return {
    {
        name = "a cue with no file behind it plays nothing instead of raising",
        fn = function()
            Sound.reset()
            -- Point a cue at a file that does not exist, so this holds regardless of what audio has
            -- landed on this machine: the tolerance is a property of the loader, not of the content.
            Sound.cues["test.missing"] = { file = "assets/audio/does_not_exist.ogg", category = "sfx" }
            assert(Sound.play("test.missing") == nil, "a missing file should play nothing")
            Sound.cues["test.missing"] = nil
        end,
    },
    {
        name = "an unknown cue id is silent rather than an error",
        fn = function()
            assert(Sound.play("no.such.cue") == nil, "an unknown id should play nothing")
            assert(Sound.music("no.such.track") == nil, "an unknown track should play nothing")
        end,
    },
    {
        name = "loading a missing file falls back to the path, exactly as sprite.lua does",
        fn = function()
            Sound.reset()
            local result = Sound.load("assets/audio/does_not_exist.ogg")
            assert(result == "assets/audio/does_not_exist.ogg",
                "expected the path back as the fallback, got " .. tostring(result))
            assert(Sound.load(nil) == nil, "nil in, nil out")
        end,
    },
    {
        name = "a failed load is cached, so a missing file is not retried on every play",
        fn = function()
            Sound.reset()
            local first = Sound.load("assets/audio/still_missing.ogg")
            local second = Sound.load("assets/audio/still_missing.ogg")
            assert(first == second, "the fallback should be memoized like a real Source")
        end,
    },
    {
        name = "stopping music that never started is safe",
        fn = function()
            Sound.reset()
            Sound.stopMusic()
            assert(Sound.currentMusic() == nil, "nothing should be playing")
        end,
    },
    {
        name = "asking for nil music stops rather than raising",
        fn = function()
            Sound.reset()
            assert(Sound.music(nil) == nil, "nil is the stop case")
            assert(Sound.currentMusic() == nil)
        end,
    },
    {
        name = "refresh is safe with nothing playing -- the settings screen calls it on every step",
        fn = function()
            Sound.reset()
            Sound.refresh()
        end,
    },
    {
        -- The arithmetic the two sliders under Master depend on.
        name = "a category's gain is its own level scaled by master",
        fn = function()
            withVolumes(100, 100, 100, function()
                assert(math.abs(Sound.volumeOf("music") - 1) < 0.001, "full is full")
            end)
            withVolumes(50, 100, 100, function()
                assert(math.abs(Sound.volumeOf("music") - 0.5) < 0.001, "master halves everything")
                assert(math.abs(Sound.volumeOf("sfx") - 0.5) < 0.001, "including effects")
            end)
            withVolumes(50, 50, 100, function()
                assert(math.abs(Sound.volumeOf("music") - 0.25) < 0.001, "the two multiply")
                assert(math.abs(Sound.volumeOf("sfx") - 0.5) < 0.001, "and do not bleed across")
            end)
        end,
    },
    {
        name = "master at zero silences everything regardless of the sliders under it",
        fn = function()
            withVolumes(0, 100, 100, function()
                assert(Sound.volumeOf("music") == 0, "music should be silent")
                assert(Sound.volumeOf("sfx") == 0, "effects should be silent")
            end)
        end,
    },
    {
        -- A typo'd category must be audible, not silent: a cue nobody can hear is a cue nobody finds.
        name = "an unknown category falls back to master rather than to silence",
        fn = function()
            withVolumes(100, 0, 0, function()
                assert(Sound.volumeOf("nonsense") == 1, "should fall back to master alone")
            end)
        end,
    },
    {
        name = "every declared cue names a file and a category the mixer knows",
        fn = function()
            local count = 0
            for id, def in pairs(Sound.cues) do
                count = count + 1
                assert(type(def.file) == "string" and def.file ~= "",
                    id .. " declares no file, so the report cannot count it")
                assert(def.file:match("^assets/audio/"),
                    id .. " points outside assets/audio: " .. def.file)
                assert(def.category == "sfx" or def.category == "music",
                    id .. " has an unmixable category: " .. tostring(def.category))
                assert(id:match("^[^.]+%.[^.]+"),
                    id .. " is not named <area>.<thing>, which is what buckets the audio report")
                if def.volume then
                    assert(def.volume > 0 and def.volume <= 1,
                        id .. " has an out-of-range volume trim: " .. tostring(def.volume))
                end
            end
            assert(count > 0, "the cue table is empty")
        end,
    },
    {
        -- The commission doc (docs/audio-commission.md) is generated from these two fields, so a cue
        -- without them is a cue nobody can source. Requiring them keeps the brief complete by
        -- construction: you cannot add a cue and forget to say what it is.
        name = "every cue carries its commission spec: a length and a description",
        fn = function()
            for id, def in pairs(Sound.cues) do
                assert(type(def.desc) == "string" and def.desc ~= "",
                    id .. " has no desc, so docs/audio-commission.md cannot brief it")
                assert(type(def.length) == "string" and def.length ~= "",
                    id .. " has no length target for the commission doc")
            end
        end,
    },
    {
        name = "no two cues claim the same file",
        fn = function()
            local byFile = {}
            for id, def in pairs(Sound.cues) do
                assert(not byFile[def.file],
                    def.file .. " is claimed by both " .. id .. " and " .. tostring(byFile[def.file]))
                byFile[def.file] = id
            end
        end,
    },
    {
        -- The report is what makes the debt visible at all, so every cue must land in exactly one
        -- bucket -- present or missing -- and the two together must account for the whole table.
        name = "the audio report counts every cue, present or missing",
        fn = function()
            local Report = require("tools.audio_report")
            local buckets, total = Report.scan()
            assert(total == 23 or total > 0, "the report found no cues")

            local counted = 0
            for _, bucket in pairs(buckets) do
                counted = counted + #bucket.present + #bucket.missing
            end
            assert(counted == total,
                "the buckets hold " .. counted .. " cues but the table has " .. total)
        end,
    },
    {
        name = "the volume options are ranges the settings screen can actually step",
        fn = function()
            local seen = 0
            for _, def in ipairs(Settings.defs) do
                if def.key:match("^volume_") then
                    seen = seen + 1
                    assert(def.kind == "range", def.key .. " must be a range to get a slider")
                    assert(def.min == 0, def.key .. " must be able to reach silence")
                    assert(def.max and def.step and def.step > 0, def.key .. " has no usable step")
                    assert(type(def.default) == "number", def.key .. " needs a numeric default")
                    assert(def.default >= def.min and def.default <= def.max,
                        def.key .. " defaults outside its own bounds")
                end
            end
            assert(seen == 3, "expected master/music/sfx, found " .. seen)
        end,
    },
    {
        name = "stepping a volume clamps at both ends rather than wrapping",
        fn = function()
            local ok, err = pcall(function()
                Settings.set("volume_master", 100)
                Settings.step("volume_master", 1)
                assert(Settings.get("volume_master") == 100, "should clamp at the top, not wrap to 0")

                Settings.set("volume_master", 0)
                Settings.step("volume_master", -1)
                assert(Settings.get("volume_master") == 0, "should clamp at the bottom")

                Settings.set("volume_master", 50)
                Settings.step("volume_master", 1)
                assert(Settings.get("volume_master") == 60, "one step is 10")
            end)
            Settings.reload()
            assert(ok, err)
        end,
    },
    {
        name = "stepping a non-range option leaves it alone",
        fn = function()
            local ok, err = pcall(function()
                local before = Settings.get("reduced_effects")
                Settings.step("reduced_effects", 1)
                assert(Settings.get("reduced_effects") == before, "a toggle is not steppable")
                assert(Settings.step("no_such_key", 1) == nil, "an unknown key is a no-op")
            end)
            Settings.reload()
            assert(ok, err)
        end,
    },
}
