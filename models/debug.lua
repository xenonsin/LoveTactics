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

-- Convenience for the common shape: `Debug.only(thing)` is `thing` in development and nil in a
-- release build, so a registry or a menu list can splice it in without an if.
function Debug.only(value)
    if not Debug.enabled then return nil end
    return value
end

return Debug
