-- Tests for models/netplay.lua: the protocol two duellists speak, run over a loopback pair.
--
-- No sockets. The session was built to be handed something with send/poll/status and never ask what
-- is underneath, so the whole protocol -- handshake, refusal, turn relay, desync detection -- is
-- exercised here in the headless suite. By the time a real socket is involved, the only thing left
-- untested is the socket.
--
-- Pure logic, runs headless.

local Netplay = require("models.netplay")
local Transport = require("models.transport")
local Combat = require("models.combat")
local Command = require("models.command")
local Character = require("models.character")
local Item = require("models.item")

local function arena(seed)
    local tiles = {}
    for y = 1, 8 do
        tiles[y] = {}
        for x = 1, 8 do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = 8, rows = 8, tiles = tiles, objective = { type = "killAll" }, seed = seed }
end

local function fighter(id, x, y)
    local char = Character.instantiate(id)
    char.traits = {}
    char.inventory = {}
    Character.addItem(char, Item.instantiate("weapon_iron_sword"))
    return { char = char, x = x, y = y }
end

local function duel(seed)
    return Combat.new(arena(seed or 99),
        { fighter("character_knight", 4, 8) }, { fighter("character_bandit", 4, 2) })
end

-- Two sessions wired to each other, each with its own recorder.
local function sessions(overrides)
    local ta, tb = Transport.loopback()
    local log = { a = {}, b = {} }

    local function make(t, side, tag, extra)
        local o = {
            transport = t, side = side, seed = 99, content = "same-content",
            onReady = function() log[tag].ready = true end,
            onCommand = function(cmd, n) log[tag][#log[tag] + 1] = { cmd = cmd, n = n } end,
            onDesync = function(n, mine, theirs)
                log[tag].desync = { n = n, mine = mine, theirs = theirs }
            end,
            onClosed = function(reason) log[tag].closed = reason end,
        }
        for k, v in pairs(extra or {}) do o[k] = v end
        return Netplay.new(o)
    end

    local a = make(ta, "party", "a", overrides and overrides.a)
    local b = make(tb, "enemy", "b", overrides and overrides.b)
    return a, b, log
end

local function pump(a, b, times)
    for _ = 1, times or 2 do a:update() b:update() end
end

return {
    {
        name = "two peers who agree shake hands and start playing",
        fn = function()
            local a, b, log = sessions()
            pump(a, b)
            assert(log.a.ready and log.b.ready, "both should have agreed")
            assert(a:isPlaying() and b:isPlaying(), "and be playing")
            assert(a.remote.side == "enemy", "each should know which side the other drives")
        end,
    },
    {
        -- A duel between two different versions or two different sets of content is not repairable
        -- mid-fight; the two are computing different rules. Catching it at handshake also means it
        -- is never mistaken later for a mysterious turn-12 desync.
        name = "peers who cannot possibly agree refuse at the handshake, with a reason",
        fn = function()
            local cases = {
                { name = "content", over = { b = { content = "modded" } }, says = "content" },
                { name = "seed",    over = { b = { seed = 12345 } },       says = "board" },
                { name = "side",    over = { b = { side = "party" } },     says = "side" },
            }
            for _, case in ipairs(cases) do
                local a, b, log = sessions(case.over)
                pump(a, b)
                assert(not a:isPlaying(), case.name .. ": the duel should not start")
                assert(log.a.closed, case.name .. ": and should say it closed")
                assert(tostring(log.a.closed):find(case.says),
                    case.name .. ": the reason should name it, got " .. tostring(log.a.closed))
            end
        end,
    },
    {
        -- The hello must NOT go out in the constructor. A socket has no peer to write to until the
        -- other window turns up, so a hello sent then goes nowhere and both peers wait forever on a
        -- message neither ever sent. A loopback pair is open from the instant it exists, which is
        -- exactly why this was invisible here until a real socket was involved -- so the case is
        -- written with a link that starts closed and opens later.
        name = "the opening hello waits for the link, and goes exactly once",
        fn = function()
            local ta, tb = Transport.loopback()
            local sent = 0
            local realSend = ta.send
            ta.send = function(s, m) sent = sent + 1 return realSend(s, m) end

            -- A link that is not ready yet.
            ta.status = function() return "connecting" end

            local a = Netplay.new({ transport = ta, side = "party", seed = 1, content = "c" })
            a:update() a:update() a:update()
            assert(sent == 0, "nothing should be sent into a link that is still connecting")

            ta.status = function() return "open" end
            a:update()
            assert(sent == 1, "one hello once the link opens, got " .. sent)
            a:update() a:update()
            assert(sent == 1, "and never a second one, got " .. sent)
        end,
    },
    {
        name = "a turn taken on one board arrives as a command on the other",
        fn = function()
            local a, b, log = sessions()
            pump(a, b)

            local cmd = { kind = "move", x = 4, y = 7 }
            assert(a:submit(cmd), "the acting peer submits its turn")
            pump(a, b)

            assert(#log.b == 1, "the other peer should have exactly one turn to apply")
            assert(log.b[1].cmd.kind == "move", "and it should be the one that was sent")
            assert(log.b[1].cmd.x == 4 and log.b[1].cmd.y == 7, "with its target intact")
            assert(log.b[1].n == 1, "numbered, so order is never in doubt")
            assert(#log.a == 0, "and a peer is never handed back its own turn")
        end,
    },
    {
        name = "turns arrive in the order they were taken",
        fn = function()
            local a, b, log = sessions()
            pump(a, b)
            a:submit({ kind = "move", x = 4, y = 7 })
            a:submit({ kind = "wait" })
            a:submit({ kind = "move", x = 4, y = 6 })
            pump(a, b)

            assert(#log.b == 3, "all three should arrive")
            assert(log.b[1].n == 1 and log.b[2].n == 2 and log.b[3].n == 3, "in order")
            assert(log.b[2].cmd.kind == "wait", "and unmuddled")
        end,
    },
    {
        name = "two boards that match report no disagreement",
        fn = function()
            local a, b, log = sessions()
            pump(a, b)
            local ca, cb = duel(), duel()
            a:report(1, ca)
            b:report(1, cb)
            pump(a, b)
            assert(not log.a.desync and not log.b.desync, "identical boards are not a desync")
            assert(a:isPlaying() and b:isPlaying(), "and play continues")
        end,
    },
    {
        -- The failure lockstep exists to notice. Both sides must see it, on the turn it happened.
        name = "two boards that differ are caught on the turn it happened, on both peers",
        fn = function()
            local a, b, log = sessions()
            pump(a, b)

            local ca, cb = duel(), duel()
            local unit = Combat.startTurn(cb)
            Command.apply(cb, unit, { kind = "move", x = unit.x, y = unit.y - 1 })

            a:report(7, ca)
            b:report(7, cb)
            pump(a, b)

            assert(log.a.desync, "peer A should have noticed")
            assert(log.b.desync, "peer B should have noticed too")
            assert(log.a.desync.n == 7, "and name the turn it happened on")
            assert(log.a.desync.mine ~= log.a.desync.theirs, "with both fingerprints to compare")
            assert(a:isDesynced() and b:isDesynced(), "the duel stops rather than playing on")
        end,
    },
    {
        -- No attempt to resynchronize: there is no state serializer, which is the entire premise of
        -- lockstep, so there is nothing to resync to.
        name = "a desynced session refuses to keep taking turns",
        fn = function()
            local a, b, log = sessions()
            pump(a, b)
            local ca, cb = duel(), duel()
            cb.clock = cb.clock + 50
            a:report(1, ca)
            b:report(1, cb)
            pump(a, b)

            assert(a:isDesynced(), "it should be desynced")
            local ok, why = a:submit({ kind = "wait" })
            assert(not ok, "and refuse further turns")
            assert(why, "with a reason: " .. tostring(why))
        end,
    },
    {
        name = "a peer leaving closes the other cleanly",
        fn = function()
            local a, b, log = sessions()
            pump(a, b)
            a:close("forfeit")
            pump(a, b)
            assert(log.b.closed == "forfeit", "the reason should travel")
            assert(not b:isPlaying(), "and the duel should end")
        end,
    },
    {
        name = "a dropped link ends the duel rather than hanging on it",
        fn = function()
            local ta, tb = Transport.loopback()
            local closed
            local a = Netplay.new({ transport = ta, side = "party", seed = 1, content = "c",
                                    onClosed = function(r) closed = r end })
            local b = Netplay.new({ transport = tb, side = "enemy", seed = 1, content = "c" })
            -- Two rounds: the first sends each hello (a session greets from update, once the link
            -- reports open), the second delivers them.
            a:update() b:update()
            a:update() b:update()
            assert(a:isPlaying(), "playing to begin with")

            ta:close()
            a:update()
            assert(not a:isPlaying(), "a closed transport should end the session")
            assert(closed and tostring(closed):find("connection"),
                "and say so: " .. tostring(closed))
        end,
    },
    {
        name = "garbage on the wire is ignored rather than fatal",
        fn = function()
            local ta, tb = Transport.loopback()
            local a = Netplay.new({ transport = ta, side = "party", seed = 1, content = "c" })
            local b = Netplay.new({ transport = tb, side = "enemy", seed = 1, content = "c" })
            a:update() b:update()
            a:update() b:update()

            tb:send("this is not lua {{{")
            tb:send("return 'a string, not a message'")
            tb:send("return { t = 'nonsense_kind' }")
            local ok = pcall(function() a:update() end)
            assert(ok, "malformed messages must not take the session down")
            assert(a:isPlaying(), "and should leave it playing")
        end,
    },
    {
        -- The fingerprint that makes the content check possible at all.
        name = "the content fingerprint is stable, and sensitive to what is loaded",
        fn = function()
            local one = Netplay.contentFingerprint()
            local two = Netplay.contentFingerprint()
            assert(one == two, "the same install should fingerprint the same")
            assert(#one == 12, "and be short enough to put in a handshake")

            local Item = require("models.item")
            local saved = Item.defs.__probe
            Item.defs.__probe = { name = "a mod's item" }
            local modded = Netplay.contentFingerprint()
            Item.defs.__probe = saved
            assert(modded ~= one, "adding content should move the fingerprint")
            assert(Netplay.contentFingerprint() == one, "and removing it should move it back")
        end,
    },
}
