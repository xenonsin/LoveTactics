-- How two duelling peers actually exchange bytes.
--
-- A transport is deliberately tiny -- four methods over strings:
--
--   t:send(message)   -- queue a string for the peer
--   t:poll()          -- list of strings arrived since last call (possibly empty)
--   t:status()        -- "connecting" | "open" | "closed"
--   t:close()
--
-- Nothing above this line knows how the bytes move. The session layer speaks commands and hashes;
-- this speaks strings. That separation is what lets the whole protocol be tested without a network
-- at all (Transport.loopback), and it is why swapping in Steam later touches one file.
--
-- WHICH TRANSPORTS EXIST DEPENDS ON THE BUILD.
--
-- Steam is the only way a shipped game finds an opponent. The loopback and localhost transports are
-- development instruments: they exist so the protocol can be exercised in the test suite and driven
-- from two windows on one machine, without needing two Steam accounts and two PCs to find out that
-- a turn was sequenced wrongly. They are registered only when models/debug.lua says this is a
-- development build, so a release cannot reach them even by asking for one by name.
--
-- The rule they follow: a debug transport may make development easier, and must never be the only
-- way something works.

local Debug = require("models.debug")

local Transport = {}

-- ---------------------------------------------------------------------------
-- Loopback: both peers in one process
-- ---------------------------------------------------------------------------

-- A pair of transports wired to each other's inbox. No sockets, no frames, no ordering surprises --
-- exactly the point. This is what the protocol specs run on, so a sequencing or desync-detection bug
-- fails in the headless suite in a second rather than in a window with a peer attached.
--
-- Returns two transports; whatever one sends, the other polls.
function Transport.loopback()
    local a, b = { inbox = {} }, { inbox = {} }

    local function make(self, peer)
        self.send = function(_, message) peer.inbox[#peer.inbox + 1] = message end
        self.poll = function()
            local got = self.inbox
            self.inbox = {}
            return got
        end
        self.status = function() return self.closed and "closed" or "open" end
        self.close = function() self.closed = true end
        return self
    end

    return make(a, b), make(b, a)
end

-- ---------------------------------------------------------------------------
-- Registry
-- ---------------------------------------------------------------------------

-- name -> factory(opts) -> transport. Steam registers itself here when it lands; the development
-- ones are spliced in only for a development build.
Transport.kinds = {}

Transport.kinds.loopback = Debug.only(function()
    local a = Transport.loopback()
    return a
end)

-- Two windows on one machine, over localhost TCP. `opts.role` is "host" or "guest".
-- Development only, for the same reason: it exists so the protocol can be driven against a real
-- socket without two Steam accounts and two PCs.
-- Anything that is not explicitly the host joins. Written this way round deliberately: the failure
-- mode when a role name does not match is that BOTH peers listen, and on Windows a second bind to
-- the same port succeeds rather than erroring, so the two sit waiting for each other with nothing
-- to show for it. Defaulting to "guest" makes a typo produce a connection refused -- which says
-- what is wrong -- instead of a silent stalemate.
Transport.kinds.localhost = Debug.only(function(opts)
    local Socket = require("models.transport_socket")
    opts = opts or {}
    if opts.role == "host" then return Socket.host(opts.port) end
    return Socket.join(opts.port)
end)

-- Is `name` available in this build? The panel asks before offering a button, so a release never
-- shows a door it cannot open.
function Transport.available(name)
    return Transport.kinds[name] ~= nil
end

-- Every transport this build can use, sorted, for a menu to enumerate.
function Transport.names()
    local out = {}
    for name in pairs(Transport.kinds) do out[#out + 1] = name end
    table.sort(out)
    return out
end

-- Open one by name. Returns the transport, or nil plus a reason -- and asking for a debug transport
-- in a release build is a plain "unknown", not a special case, because as far as that build is
-- concerned it does not exist.
function Transport.open(name, opts)
    local factory = Transport.kinds[name]
    if not factory then return nil, "no transport named " .. tostring(name) end
    return factory(opts)
end

return Transport
