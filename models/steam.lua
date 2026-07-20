-- Loading Steam, once, and admitting when it is not there.
--
-- luasteam is a native binding with three separate things that have to be present before a single
-- call works, and each fails differently:
--
--   1. luasteam.dll        -- the binding itself, from github.com/uspgamedev/luasteam/releases
--   2. steam_api64.dll     -- the Steam API library, from the Steamworks SDK (partner site, v1.64)
--   3. steam_appid.txt     -- your App ID, or 480 (Spacewar) while developing
--
-- ...plus the Steam client actually running. All of them live beside the executable.
--
-- WHY THIS MODULE EXISTS RATHER THAN A require() AT THE POINT OF USE. Two reasons, both learned from
-- the docs rather than from running it:
--
--   * `require "luasteam"` will not find a DLL sitting next to the .love file on its own -- LOVE's
--     package.cpath does not include that directory, so the search path has to be widened first.
--   * Steam has to be Init()ed before any interface answers, and Shutdown() on the way out. Doing
--     that per-transport would mean initialising it several times or not at all.
--
-- Everything here degrades to "not available, and here is why" rather than raising. A game that
-- cannot reach Steam should say so in a menu; it should not fail to start.

local Steam = {}

Steam.available = false
Steam.reason = "not initialised yet"
Steam.api = nil

-- Widen the C module search path to the places a shipped LOVE game actually keeps its DLLs: beside
-- the executable, and beside the .love. Harmless when they are already covered.
local function widenSearchPath()
    local sep = package.config:sub(1, 1)
    local ext = (sep == "\\") and "dll" or "so"
    local roots = {}

    if love and love.filesystem then
        local src = love.filesystem.getSource()
        local dir = love.filesystem.getSourceBaseDirectory()
        if src then roots[#roots + 1] = src end
        if dir then roots[#roots + 1] = dir end
    end
    roots[#roots + 1] = "."

    for _, root in ipairs(roots) do
        local entry = root .. sep .. "?." .. ext
        if not package.cpath:find(entry, 1, true) then
            package.cpath = package.cpath .. ";" .. entry
        end
    end
end

-- Try to bring Steam up. Safe to call more than once; only the first does anything.
-- Returns true, or false plus a reason fit to show a player.
function Steam.init()
    if Steam.available then return true end
    if Steam.attempted then return false, Steam.reason end
    Steam.attempted = true

    widenSearchPath()

    local ok, api = pcall(require, "luasteam")
    if not ok or not api then
        Steam.reason = "luasteam is not installed with this build"
        return false, Steam.reason
    end

    -- Init fails when the client is not running, when steam_appid.txt is missing, or when the app
    -- id is one this account cannot run. The binding reports a plain false, so the reason below is
    -- necessarily a guess at the common causes -- which is still better than a bare failure.
    local started = false
    local initOk, err = pcall(function() started = api.init() end)
    if not initOk then
        Steam.reason = "Steam failed to start: " .. tostring(err)
        return false, Steam.reason
    end
    if not started then
        Steam.reason = "Steam is not running, or steam_appid.txt is missing"
        return false, Steam.reason
    end

    Steam.api = api
    Steam.available = true
    Steam.reason = nil
    return true
end

-- Pump Steam's callbacks. Everything asynchronous -- messages arriving, a friend accepting an
-- invite -- is delivered through these, so a frame that skips this is a frame Steam is mute in.
function Steam.runCallbacks()
    if Steam.available and Steam.api and Steam.api.runCallbacks then
        pcall(Steam.api.runCallbacks)
    end
end

function Steam.shutdown()
    if Steam.available and Steam.api and Steam.api.shutdown then
        pcall(Steam.api.shutdown)
    end
    Steam.available = false
    Steam.api = nil
end

return Steam
