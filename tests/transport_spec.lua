-- Tests for models/transport.lua: the byte-moving seam, and the build gate over it.
--
-- Two things worth asserting. The loopback pair has to behave like a real link (ordered, drains on
-- poll, one direction does not eat the other's mail), because every protocol spec is going to run on
-- it and a lying test rig is worse than none. And the debug gate has to actually gate: a release
-- build must not be able to reach a development transport even by asking for it by name.
--
-- Pure logic, runs headless.

local Transport = require("models.transport")
local Debug = require("models.debug")

-- Run `fn` with the build switch forced, always restoring it. The registry is built at require time
-- from the flag, so the gate is re-read through Transport.kinds rather than by reloading the module.
local function withDebug(enabled, fn)
    local saved = Debug.enabled
    local savedKinds = {}
    for k, v in pairs(Transport.kinds) do savedKinds[k] = v end
    Debug.enabled = enabled
    if not enabled then
        for k in pairs(Transport.kinds) do Transport.kinds[k] = nil end
    end
    local ok, err = pcall(fn)
    Debug.enabled = saved
    for k in pairs(Transport.kinds) do Transport.kinds[k] = nil end
    for k, v in pairs(savedKinds) do Transport.kinds[k] = v end
    if not ok then error(err, 0) end
end

return {
    {
        name = "a loopback pair carries messages both ways, in order",
        fn = function()
            local a, b = Transport.loopback()
            a:send("one")
            a:send("two")
            b:send("back")

            local atB = b:poll()
            assert(#atB == 2, "both messages should arrive, got " .. #atB)
            assert(atB[1] == "one" and atB[2] == "two", "and in the order they were sent")

            local atA = a:poll()
            assert(#atA == 1 and atA[1] == "back", "the other direction is its own channel")
        end,
    },
    {
        name = "polling drains, so a message is delivered once",
        fn = function()
            local a, b = Transport.loopback()
            a:send("only once")
            assert(#b:poll() == 1, "first poll delivers")
            assert(#b:poll() == 0, "second poll has nothing left")
            assert(#b:poll() == 0, "and stays empty")
        end,
    },
    {
        name = "an idle link polls empty rather than blocking or erroring",
        fn = function()
            local a, b = Transport.loopback()
            local got = b:poll()
            assert(type(got) == "table" and #got == 0, "an empty poll is an empty list")
            assert(a:status() == "open", "and the link is open until closed")
            a:close()
            assert(a:status() == "closed", "closing says so")
        end,
    },
    {
        -- The gate the user asked for: in a shipped build, Steam is the only way. A development
        -- transport must not merely be hidden from the menu -- it must not be reachable at all.
        name = "a release build cannot open a development transport, even by name",
        fn = function()
            withDebug(false, function()
                assert(not Transport.available("loopback"),
                    "loopback should not exist in a release build")
                assert(#Transport.names() == 0 or not Transport.available("localhost"),
                    "nor should any other development transport")

                local t, why = Transport.open("loopback")
                assert(t == nil, "asking for it by name should still fail")
                assert(why and why:find("no transport"),
                    "and read as simply unknown: " .. tostring(why))
            end)
        end,
    },
    {
        -- Cost an afternoon. The command line says "join", the factory tested for "guest", so the
        -- joiner opened a HOST transport -- and on Windows a second bind to the same port succeeds
        -- rather than erroring, so both windows sat listening, each waiting for the other, with
        -- nothing on screen to say why. Anything that is not explicitly the host now joins, so a
        -- mismatched name produces a connection refused (which says what is wrong) rather than a
        -- silent stalemate.
        name = "only an explicit host listens; every other role joins",
        fn = function()
            local factory = Transport.kinds.localhost
            assert(factory, "the localhost transport should exist in a development build")

            local host = factory({ role = "host", port = 51520 })
            assert(host.kind == "host", "'host' listens")
            host:close()

            for _, role in ipairs({ "guest", "join", "client", "", nil }) do
                local t = factory({ role = role, port = 51521 })
                assert(t.kind == "guest",
                    "role " .. tostring(role) .. " should join, not listen")
                t:close()
            end
        end,
    },
    {
        name = "a development build has the development transports",
        fn = function()
            withDebug(true, function()
                assert(Transport.available("loopback"), "loopback is a development instrument")
                local names = Transport.names()
                assert(#names > 0, "and should be enumerable for a debug menu")
            end)
        end,
    },
}
