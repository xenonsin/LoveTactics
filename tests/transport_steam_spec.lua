-- Tests for models/transport_steam.lua, against a test double rather than Steam.
--
-- Be clear about what this does and does not prove. luasteam is a native binding that is not
-- vendored here, and running it needs the Steam client, an appid, and a second account on a second
-- machine. NONE of that is exercised. What is exercised is everything the transport does around
-- those calls -- state, draining, failure handling, refusing to start without a peer -- which is
-- most of the code and all of the logic.
--
-- The four calls that actually touch luasteam live in one adapter function, precisely so the
-- unverified surface is small enough to name. When Steam misbehaves, look there first.
--
-- Pure logic, runs headless.

local Steam = require("models.transport_steam")
local Transport = require("models.transport")

-- Stands in for the luasteam adapter: the same four functions, over a table.
local function fakeApi()
    local api = { sent = {}, inbox = {}, accepted = {}, callbacks = 0 }
    api.send = function(peer, data) api.sent[#api.sent + 1] = { peer = peer, data = data } return true end
    api.receive = function()
        local got = api.inbox
        api.inbox = {}
        return got
    end
    api.accept = function(peer) api.accepted[#api.accepted + 1] = peer return true end
    api.runCallbacks = function() api.callbacks = api.callbacks + 1 end
    return api
end

return {
    {
        name = "a peer's id is required, and its absence is said plainly",
        fn = function()
            local t = Steam.new({ api = fakeApi() })
            assert(t:status() == "closed", "no peer means no link")
            assert(t.error and t.error:find("peer"), "and it should say so: " .. tostring(t.error))
            assert(t:send("anything") == false, "sending goes nowhere")
            assert(#t:poll() == 0, "and nothing arrives")
        end,
    },
    {
        -- The case that matters for a build without the native binding: it must fail with a reason,
        -- not by throwing on require.
        name = "a build with no luasteam closes with a reason rather than exploding",
        fn = function()
            local ok, t = pcall(Steam.new, { peer = "76561198000000000" })
            assert(ok, "constructing without luasteam must not raise: " .. tostring(t))
            assert(t:status() == "closed", "it should simply be closed")
            assert(t.error, "with something to show the player: " .. tostring(t.error))
        end,
    },
    {
        name = "a link with a peer opens and sends to that peer",
        fn = function()
            local api = fakeApi()
            local t = Steam.new({ peer = "peer-1", api = api })
            assert(t:status() == "open", "there is no connect step to wait on")

            assert(t:send("hello"), "a message should go")
            assert(#api.sent == 1, "and reach the adapter")
            assert(api.sent[1].peer == "peer-1", "addressed to the peer")
            assert(api.sent[1].data == "hello", "carrying what was sent")
        end,
    },
    {
        -- A peer who messages first opens a session that has to be accepted before anything flows.
        name = "the session with the peer is accepted on the way up",
        fn = function()
            local api = fakeApi()
            Steam.new({ peer = "peer-2", api = api })
            assert(#api.accepted == 1 and api.accepted[1] == "peer-2",
                "the session should have been accepted")
        end,
    },
    {
        name = "polling drains whole messages, with no framing to reassemble",
        fn = function()
            local api = fakeApi()
            local t = Steam.new({ peer = "p", api = api })

            -- luasteam hands back tables with a `data` field; a plain string is tolerated too.
            api.inbox = { { data = "one" }, { data = "two" }, "three" }
            local got = t:poll()
            assert(#got == 3, "all three should arrive, got " .. #got)
            assert(got[1] == "one" and got[2] == "two" and got[3] == "three",
                "in order, unwrapped")
            assert(#t:poll() == 0, "and a second poll finds nothing left")
        end,
    },
    {
        name = "callbacks are pumped while polling, since Steam delivers through them",
        fn = function()
            local api = fakeApi()
            local t = Steam.new({ peer = "p", api = api })
            t:poll() t:poll()
            assert(api.callbacks == 2, "each poll should run callbacks, got " .. api.callbacks)
        end,
    },
    {
        -- An error out of the native binding must close the link, not propagate into the game loop.
        name = "a failing send or receive closes the link instead of raising",
        fn = function()
            local api = fakeApi()
            api.send = function() error("steam exploded") end
            local t = Steam.new({ peer = "p", api = api })
            local ok = pcall(function() return t:send("x") end)
            assert(ok, "a failure inside Steam must not raise into the caller")
            assert(t:status() == "closed", "the link should close")
            assert(t.error and t.error:find("send failed"), "and name what went wrong")

            local api2 = fakeApi()
            api2.receive = function() error("steam exploded") end
            local t2 = Steam.new({ peer = "p", api = api2 })
            local ok2, got = pcall(function() return t2:poll() end)
            assert(ok2 and type(got) == "table", "poll should answer with an empty list")
            assert(t2:status() == "closed", "and close the link")
        end,
    },
    {
        name = "closing stops it sending",
        fn = function()
            local api = fakeApi()
            local t = Steam.new({ peer = "p", api = api })
            t:close()
            assert(t:status() == "closed", "closed is closed")
            assert(t:send("x") == false, "and nothing more goes out")
            assert(#api.sent == 0, "not even to the adapter")
        end,
    },
    {
        -- The one that matters for shipping: Steam is registered in EVERY build, unlike the
        -- development transports. A release with no multiplayer in the menu would be a worse bug
        -- than one that says why it cannot connect.
        name = "Steam is available in every build, development or not",
        fn = function()
            assert(Transport.available("steam"),
                "the steam transport must be registered unconditionally")
            local t = Transport.open("steam", { peer = "someone" })
            assert(t, "and opening it should always hand something back")
            assert(t.status, "that behaves like a transport")
        end,
    },
    {
        -- The end-to-end case: a real Netplay session, over two real SteamTransports, with only the
        -- native binding faked. Handshake, a turn crossing, and fingerprints exchanged -- all of it
        -- through the Steam transport's own interface rather than a loopback that behaves nothing
        -- like it. After this, the unverified surface is four calls in steamApi().
        name = "a whole session runs over a pair of Steam transports",
        fn = function()
            local Netplay = require("models.netplay")

            -- Two fake APIs that deliver into each other's inbox, the way the relay would.
            local aApi, bApi = fakeApi(), fakeApi()
            aApi.send = function(_, data) bApi.inbox[#bApi.inbox + 1] = { data = data } return true end
            bApi.send = function(_, data) aApi.inbox[#aApi.inbox + 1] = { data = data } return true end

            local ta = Steam.new({ peer = "B", api = aApi })
            local tb = Steam.new({ peer = "A", api = bApi })
            assert(ta:status() == "open" and tb:status() == "open", "both links open")

            local ready, got = { }, { }
            local a = Netplay.new({ transport = ta, side = "party", seed = 7, content = "c",
                onReady = function() ready.a = true end,
                onCommand = function(cmd, n) got[#got + 1] = { cmd = cmd, n = n } end })
            local b = Netplay.new({ transport = tb, side = "enemy", seed = 7, content = "c",
                onReady = function() ready.b = true end })

            for _ = 1, 4 do a:update() b:update() end
            assert(ready.a and ready.b, "the handshake should complete over Steam's shape")
            assert(a:isPlaying() and b:isPlaying(), "and both should be playing")

            b:submit({ kind = "move", x = 4, y = 3 })
            for _ = 1, 3 do a:update() b:update() end
            assert(#got == 1, "the turn should cross, got " .. #got)
            assert(got[1].cmd.kind == "move" and got[1].cmd.y == 3, "intact")

            -- And a disagreement is still caught through this transport.
            a.myHashes[1] = "aaaaaaaaaaaa"
            b.myHashes[1] = "bbbbbbbbbbbb"
            local desync
            a.onDesync = function(n) desync = n end
            b:say({ t = "hash", n = 1, digest = "bbbbbbbbbbbb" })
            a:update()
            assert(desync == 1, "a desync must still be caught over Steam")
        end,
    },
    {
        name = "it satisfies the transport contract the session speaks to",
        fn = function()
            local t = Steam.new({ peer = "p", api = fakeApi() })
            for _, method in ipairs({ "send", "poll", "status", "close" }) do
                assert(type(t[method]) == "function", "a transport owes " .. method)
            end
            assert(type(t:poll()) == "table", "poll answers with a list")
            assert(type(t:status()) == "string", "status answers with a string")
        end,
    },
}
