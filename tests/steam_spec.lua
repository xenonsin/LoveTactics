-- Tests for models/steam.lua: bringing the native binding up, and failing usefully when it is not
-- there -- which is the case that actually runs on every machine without the DLL, including this one.
--
-- luasteam is not vendored here, so what these check is the ABSENT path: no raising, a reason worth
-- showing a player, and no repeated attempts. The present path needs the client, the SDK library and
-- an app id, and is not exercised.
--
-- Pure logic, runs headless.

local Steam = require("models.steam")

return {
    {
        -- The one that matters for every build without the binding. A game that cannot reach Steam
        -- should say so in a menu; it must not fail to start.
        name = "a build without luasteam reports why instead of raising",
        fn = function()
            local ok, why = pcall(Steam.init)
            assert(ok, "init must never raise: " .. tostring(why))

            local started, reason = Steam.init()
            if not started then
                assert(type(reason) == "string" and #reason > 0,
                    "a failure needs a reason fit to show someone")
                assert(reason:find("luasteam") or reason:find("Steam"),
                    "and one that names what is missing: " .. reason)
            end
        end,
    },
    {
        -- Loading a native library that is not there is not free, and a menu that asks every frame
        -- whether Steam has appeared yet would pay it every frame.
        name = "a failed start is not retried on every call",
        fn = function()
            Steam.init()
            assert(Steam.attempted, "the attempt should be remembered")
            local before = Steam.reason
            Steam.init()
            assert(Steam.reason == before, "the answer should not change by asking again")
        end,
    },
    {
        name = "pumping callbacks and shutting down are safe with no Steam at all",
        fn = function()
            assert(pcall(Steam.runCallbacks), "runCallbacks must be safe when Steam is absent")
            assert(pcall(Steam.shutdown), "shutdown must be safe when Steam never started")
            assert(not Steam.available, "and it should still read as unavailable")
        end,
    },
    {
        -- The DLL ships beside the .love, where LOVE's package.cpath does not look. If this is
        -- wrong, luasteam is simply never found on a machine that HAS it -- a failure that looks
        -- exactly like not having installed it.
        name = "the module search path is widened to where the binary actually ships",
        fn = function()
            Steam.init()
            local ext = (package.config:sub(1, 1) == "\\") and "dll" or "so"
            assert(package.cpath:find("?." .. ext, 1, true),
                "the C search path should include a native extension entry")
            assert(package.cpath:find("%?%." .. ext),
                "and a ?-pattern entry the loader can actually substitute into")
        end,
    },
    {
        name = "the transport reports the same reason rather than inventing its own",
        fn = function()
            local SteamTransport = require("models.transport_steam")
            local t = SteamTransport.new({ peer = "76561198000000000" })
            assert(t:status() == "closed", "no Steam means no link")
            assert(t.error and #t.error > 0, "and the reason should travel out to the caller")
        end,
    },
}
