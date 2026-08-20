-- The one switch that says whether this is a development build.
--
-- It existed already, as a `local DEBUG = true` in states/menu.lua guarding the extra menu buttons.
-- That was fine while the only thing it gated was two buttons in one file. It stopped being fine
-- once something had to be gated ACROSS modules -- a debug-only network transport is decided in the
-- transport registry, offered (or not) by the duel panel, and reachable (or not) from the command
-- line, and three copies of the same boolean is how one of them ends up shipped switched on.
--
-- The rule for anything gated here: a debug affordance may make development easier, and must never
-- be the only way something works. Local-socket duels exist so two windows on one machine can test
-- the protocol without Steam accounts; a shipped build matches through Steam and nothing else.
--
-- Flip `enabled` to false for a release build.

local Debug = {}

Debug.enabled = true

-- Runtime toggles a developer flips from inside the game to test content out of order. Unlike
-- `enabled` (a build constant), these change during a session -- so every reader must AND them with
-- `enabled`, and the affordance that flips them must only exist when `enabled`. That keeps the rule
-- above intact: a release build (enabled = false) can neither show the switch nor honour the flag.
--
--   showAllQuests  the Quest Board drops every gate, so a locked or prerequisite-gated line can be
--                  run without progressing to it naturally (models/quest.lua).
--   allItems       the Loadout stash becomes the full item catalog, restocked as it is spent, so any
--                  item can be equipped and tested (ui/panels/party.lua).
Debug.showAllQuests = false
Debug.allItems = false

-- True only when both the build allows debug affordances AND the named flag is on. The one call the
-- readers make, so a flag can never be honoured in a build that forbids it.
function Debug.on(flag)
    return Debug.enabled and Debug[flag] == true
end

-- Convenience for the common shape: `Debug.only(thing)` is `thing` in development and nil in a
-- release build, so a registry or a menu list can splice it in without an if.
function Debug.only(value)
    if not Debug.enabled then return nil end
    return value
end

-- ---------------------------------------------------------------------------
-- Jump to source
-- ---------------------------------------------------------------------------

-- Open one of the project's own files in an editor, optionally at `line`. This is the plumbing under
-- every "edit this blueprint" affordance -- the one on the conversation overlay (ui/dialogue.lua)
-- first -- so that reading a line in the game and fixing its wording are one gesture apart instead of
-- a hunt through data/ for the file it came out of.
--
-- `rel` is a project-relative path exactly as love.filesystem spells it
-- ("data/conversations/prologue/conversation_prologue_sponsor.lua"); it is resolved against the
-- launched source directory, which is where the file a `require` actually read lives.
--
-- Three ways in, in order, because there is no portable "open this in the user's editor":
--   1. $LOVETACTICS_EDITOR, a command template. `{file}` and `{line}` are substituted; a template
--      naming neither gets the quoted path appended. This is the only one that can be right for an
--      editor we have never heard of, so it wins.
--        LOVETACTICS_EDITOR=code -g {file}:{line}
--        LOVETACTICS_EDITOR=subl
--   2. VS Code, if `code` answers on PATH -- the editor this project is written in, and the reason
--      the line number is worth carrying at all: `code -g` lands the caret ON the line.
--   3. love.system.openURL, which hands the file to the OS and lands wherever .lua is associated.
--      No line number survives a file:// URL, so this one opens at the top.
--
-- Returns true if something was launched. It never raises: a debug shortcut that crashes the game
-- when an editor is missing is worse than one that quietly does nothing, and the caller prints the
-- path to the console either way, so the fallback of last resort is copying it out of there.
local probedCode

-- Is `code` on PATH? Probed once and remembered -- the check itself spawns a shell, and doing that on
-- every click is how a debug button starts flashing a console window.
local function hasVSCode()
    if probedCode == nil then
        local probe = (love.system.getOS() == "Windows") and "where code >nul 2>nul" or "command -v code >/dev/null 2>&1"
        -- LuaJIT's os.execute answers with the exit code (0 = found); guard for a boolean anyway,
        -- since a false here only costs us the fallback, not the feature.
        local result = os.execute(probe)
        probedCode = result == 0 or result == true
    end
    return probedCode
end

-- Run `cmd` without the game waiting on the editor to be closed again. `os.execute` blocks until the
-- child exits, which for a plain `notepad "file"` means the game is frozen until you are done editing
-- -- so the command is detached: `start` on Windows, a background `&` elsewhere.
local function spawn(cmd)
    if love.system.getOS() == "Windows" then
        os.execute('start "" ' .. cmd)
    else
        os.execute(cmd .. " &")
    end
end

function Debug.openFile(rel, line)
    if not Debug.enabled or not rel then return false end
    local abs = love.filesystem.getSource() .. "/" .. rel
    line = tonumber(line) or 1

    local template = os.getenv("LOVETACTICS_EDITOR")
    if template and template ~= "" then
        local cmd = template:gsub("{file}", '"' .. abs .. '"'):gsub("{line}", tostring(line))
        if not template:find("{file}", 1, true) then cmd = cmd .. ' "' .. abs .. '"' end
        spawn(cmd)
        return true
    end

    local ok = pcall(hasVSCode)
    if ok and probedCode then
        spawn('code -g "' .. abs .. ":" .. line .. '"')
        return true
    end

    local ran, opened = pcall(love.system.openURL, "file://" .. abs)
    return ran and opened == true
end

return Debug
