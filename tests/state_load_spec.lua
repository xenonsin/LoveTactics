-- THE STATE MODULES COMPILE, which is the one thing a green suite otherwise says nothing about.
--
-- No spec in this directory requires states/battle.lua or states/game.lua -- they are the two biggest
-- files in the project, they own every screen the player actually touches, and they are loaded for the
-- first time when somebody starts a quest. A syntax error or a stray reference in either one ships
-- green and crashes on the first real board.
--
-- WHAT THIS DOES AND DOES NOT CATCH. `love.filesystem.load` compiles a chunk without running it, so
-- this catches parse errors, unbalanced blocks and a truncated file. It does NOT catch a call to a
-- forward-declared local made above its `local` line -- that compiles cleanly and resolves to a nil
-- global at run time. Nothing short of driving the screen catches that one; see .claude/skills/verify.
--
-- Kept deliberately cheap: compiling is not running, so this costs milliseconds and pulls in no
-- graphics. Every state is listed rather than globbed, so deleting one is a decision somebody makes
-- here rather than a case that quietly stops running.

local STATES = {
    "states/init.lua",
    "states/menu.lua",
    "states/hub.lua",
    "states/game.lua",
    "states/battle.lua",
    "states/draft.lua",
    "states/prologue.lua",
    "states/credits.lua",
    "states/settings.lua",
    "states/character_creation.lua",
    "states/build_select.lua",
    "states/debug_editor.lua",
    "states/duel_debug.lua",
    "main.lua",
}

local cases = {}
for _, path in ipairs(STATES) do
    cases[#cases + 1] = {
        name = path .. " compiles",
        fn = function()
            local chunk, err = love.filesystem.load(path)
            assert(chunk, path .. " does not compile: " .. tostring(err))
        end,
    }
end

return cases
