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
-- Two ways in, in order, because there is no portable "open this in the user's editor":
--   1. $LOVETACTICS_EDITOR, a command template. `{file}` and `{line}` are substituted; a template
--      naming neither gets the quoted path appended. This is the only one that can be right for an
--      editor we have never heard of, so it wins.
--        LOVETACTICS_EDITOR=code -g {file}:{line}
--        LOVETACTICS_EDITOR=subl
--   2. A URL handed to the OS. `vscode://file/<path>:<line>` first -- VS Code registers that scheme
--      on every platform it installs on, and it is the only URL form that carries a line number, so
--      the caret lands ON the line. If nothing answers it, `file://<path>`, which opens wherever
--      .lua is associated, at the top.
--
-- It deliberately does NOT shell out to look for an editor. `code` on PATH is a .cmd shim, and a
-- windowed LOVE build has no console for a child process to borrow: every `os.execute` -- the `where
-- code` probe as much as the `start "" code` that followed it -- allocates a console window, and the
-- one wrapping a batch file stays on screen after the editor is up. The scheme handler is registered
-- against Code.exe directly, so ShellExecute reaches it without a shell in between. The template is
-- the one path left that can spawn a console, and only because the user asked for a command by name.
--
-- Returns true if something was launched. It never raises: a debug shortcut that crashes the game
-- when an editor is missing is worse than one that quietly does nothing, and the caller prints the
-- path to the console either way, so the fallback of last resort is copying it out of there.

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

-- Percent-encode a filesystem path into the path half of a URL. Windows spells paths with
-- backslashes and the project can sit under a folder with a space in it; either one makes a URL the
-- OS refuses or truncates. Everything outside the unreserved set survives as %XX, except the `/` and
-- `:` a path needs to keep (`E:/Projects/...`).
local function urlPath(abs)
    local encoded = abs:gsub("\\", "/"):gsub("[^%w%-%._~/:]", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return encoded
end

-- Hand a URL to the OS. Wrapped because openURL is missing under the headless test runner, and
-- because a false here is a fallback rather than a failure.
local function openURL(url)
    local ran, opened = pcall(love.system.openURL, url)
    return ran and opened == true
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

    local path = urlPath(abs)
    if openURL("vscode://file/" .. path .. ":" .. line .. ":1") then return true end

    -- file:// wants an absolute path rooted at `/`; a Windows path starts at its drive letter.
    if path:sub(1, 1) ~= "/" then path = "/" .. path end
    return openURL("file://" .. path)
end

return Debug
