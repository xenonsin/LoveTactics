-- The Steam transport: how a shipped game reaches an opponent.
--
-- UNVERIFIED IN THIS REPOSITORY, and honestly labelled as such. luasteam is a native binding that is
-- not vendored here, and exercising it needs the Steam client running, an appid, and a second
-- account on a second machine. Everything below was written against the documented luasteam surface
-- and has NOT been run against the real one. Treat the adapter at the bottom as the part to check
-- first when it misbehaves.
--
-- What IS tested is everything else, and that is deliberate. The transport's own logic -- framing,
-- draining, connection state, what happens when a peer has not accepted yet -- goes through an
-- injectable `api`, so a test double stands in for luasteam and the specs cover the behaviour. The
-- only unverified surface left is the handful of calls in steamApi(): four functions.
--
-- The same trick as the in-memory backend in models/builds.lua, for the same reason. A seam narrow
-- enough to fake is a seam narrow enough to be wrong in only a few places.
--
-- WHY MESSAGES RATHER THAN SOCKETS. ISteamNetworkingMessages sends to a SteamID and lets Valve's
-- relay work out how -- no ports, no NAT punching, no address to exchange. For a friend invite,
-- which is how this game matches (see the plan), that is the entire problem solved.
--
-- Channel and reliability: one reliable channel. A turn-based duel has nothing to gain from an
-- unreliable one -- a dropped command does not degrade a lockstep game, it desyncs it -- and the
-- volume is a few hundred bytes every several seconds.

local SteamTransport = {}
SteamTransport.__index = SteamTransport

SteamTransport.CHANNEL = 0

-- Send reliably. luasteam mirrors the C++ constant (k_nSteamNetworkingSend_Reliable = 8).
SteamTransport.SEND_RELIABLE = 8

-- ---------------------------------------------------------------------------
-- The adapter: the only part that touches luasteam
-- ---------------------------------------------------------------------------

-- Four functions over a peer's SteamID. Everything above this is plain Lua and is specced.
local function steamApi()
    local ok, steam = pcall(require, "luasteam")
    if not ok or not steam then return nil, "luasteam is not available in this build" end
    local messages = steam.networkingMessages
    if not messages then return nil, "this luasteam build has no networkingMessages" end

    return {
        send = function(peer, data)
            return messages.sendMessageToUser(peer, data,
                SteamTransport.SEND_RELIABLE, SteamTransport.CHANNEL)
        end,
        -- Raw, exactly as luasteam hands them over. Unwrapping happens in poll() rather than here,
        -- so the shape-handling is covered by specs instead of sitting in the one function nothing
        -- can test.
        receive = function()
            return messages.receiveMessagesOnChannel(SteamTransport.CHANNEL, 32) or {}
        end,
        -- A peer that messages us first opens a session we have to accept before anything flows.
        accept = function(peer) return messages.acceptSessionWithUser(peer) end,
        runCallbacks = function() if steam.runCallbacks then steam.runCallbacks() end end,
    }
end

-- ---------------------------------------------------------------------------
-- Transport
-- ---------------------------------------------------------------------------

-- opts = {
--   peer     = <SteamID of the other player>,   -- required
--   invited  = true,                            -- we accepted THEIR invite, so accept their session
--   api      = <adapter>,                       -- injected in tests; defaults to luasteam
-- }
function SteamTransport.new(opts)
    opts = opts or {}
    local self = setmetatable({
        peer = opts.peer,
        queue = {},
        state = "connecting",
    }, SteamTransport)

    if not self.peer then
        self.state = "closed"
        self.error = "no peer to duel"
        return self
    end

    local api, why = opts.api, nil
    if not api then api, why = steamApi() end
    if not api then
        self.state = "closed"
        self.error = why or "no Steam networking"
        return self
    end
    self.api = api

    -- Accepting is only meaningful for the side that was invited; the inviter's first message opens
    -- the session on the other end. Harmless to call either way, so it is not gated on being sure.
    if api.accept then pcall(api.accept, self.peer) end

    -- There is no connect step to wait on: a message to a SteamID is routed by the relay whether or
    -- not the peer has drained anything yet. The link is open as soon as we have somewhere to send.
    self.state = "open"
    return self
end

function SteamTransport:send(message)
    if self.state ~= "open" or not self.api then return false end
    local ok, err = pcall(self.api.send, self.peer, message)
    if not ok then
        self.state = "closed"
        self.error = "send failed: " .. tostring(err)
        return false
    end
    return true
end

-- Whole messages since the last call. No framing: ISteamNetworkingMessages preserves message
-- boundaries the way a datagram does, so unlike the TCP transport there is nothing to reassemble.
function SteamTransport:poll()
    if self.state ~= "open" or not self.api then return {} end
    if self.api.runCallbacks then pcall(self.api.runCallbacks) end
    local ok, got = pcall(self.api.receive)
    if not ok then
        self.state = "closed"
        self.error = "receive failed: " .. tostring(got)
        return {}
    end

    -- luasteam hands back a table carrying the payload on `data`; a plain string is tolerated too,
    -- since that is the shape its docs show in places. Done HERE rather than in the adapter so the
    -- shape-handling is specced -- it is exactly the sort of detail a binding gets wrong, and the
    -- adapter is the one place nothing can check.
    local out = {}
    for _, msg in ipairs(got or {}) do
        out[#out + 1] = (type(msg) == "table" and msg.data) or msg
    end
    return out
end

function SteamTransport:status()
    return self.state
end

function SteamTransport:close()
    self.state = "closed"
end

return SteamTransport
