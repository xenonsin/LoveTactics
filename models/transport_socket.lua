-- A localhost TCP transport, for driving a duel from two windows on one machine.
--
-- DEVELOPMENT ONLY. It is registered into the transport table exclusively for a debug build (see
-- models/transport.lua and models/debug.lua); a shipped game matches through Steam and has no way to
-- reach this, by name or otherwise. It exists so the protocol can be exercised against a real socket
-- -- real serialization, real arrival timing, real disconnects -- without needing two Steam accounts
-- and two PCs to discover that a turn was sequenced wrongly.
--
-- TCP RATHER THAN UDP, deliberately. On loopback, UDP loss is close to zero and "close to" is the
-- problem: a single dropped command does not degrade a lockstep duel, it desyncs it, and then the
-- afternoon goes on hunting a determinism bug that was really a lost packet. TCP's ordering and
-- redelivery cost a length prefix and remove the whole category.
--
-- Everything is non-blocking. A transport that stalls the frame while waiting for a peer would make
-- the game unresponsive, and worse, would hide timing bugs behind its own pauses.

local socket = require("socket")

local SocketTransport = {}
SocketTransport.__index = SocketTransport

SocketTransport.DEFAULT_PORT = 51337
SocketTransport.HOST = "127.0.0.1"

-- Frames are an 8-digit decimal length then the payload. TCP is a stream, not a sequence of
-- messages: without a prefix, two commands sent in the same breath arrive as one string and a
-- command longer than the read buffer arrives in halves.
local HEADER = 8

local function frame(message)
    return string.format("%08d", #message) .. message
end

local function new(kind)
    return setmetatable({
        kind = kind,
        inbuf = "",
        queue = {},
        state = "connecting",
    }, SocketTransport)
end

-- ---------------------------------------------------------------------------
-- Opening
-- ---------------------------------------------------------------------------

-- Wait for the other window. Returns a transport immediately, in "connecting" until the peer
-- arrives -- the caller keeps polling, and the game keeps drawing meanwhile.
function SocketTransport.host(port)
    local self = new("host")
    local server, err = socket.bind(SocketTransport.HOST, port or SocketTransport.DEFAULT_PORT)
    if not server then
        self.state = "closed"
        self.error = "could not listen: " .. tostring(err)
        return self
    end
    server:settimeout(0)
    self.server = server
    return self
end

-- Knock on a waiting host, and keep knocking. A guest launched before the host would otherwise get
-- "connection refused" once and give up, which is the ordinary case when two windows are started by
-- hand a second apart.
function SocketTransport.join(port)
    local self = new("guest")
    self.port = port or SocketTransport.DEFAULT_PORT
    self.retry = 0
    return self
end

-- ---------------------------------------------------------------------------
-- Pumping
-- ---------------------------------------------------------------------------

-- Accept the guest, or finish connecting to the host. Cheap and idempotent, so it can live at the
-- top of poll().
function SocketTransport:advance()
    if self.state ~= "connecting" then return end

    if self.server and not self.client then
        local client = self.server:accept()
        if client then
            client:settimeout(0)
            self.client = client
            self.state = "open"
        end
        return
    end

    if self.kind == "guest" then
        if not self.client then
            local client = socket.tcp()
            client:settimeout(0)
            local ok, err = client:connect(SocketTransport.HOST, self.port)
            if ok or err == "already connected" then
                self.client = client
                self.state = "open"
                return
            end
            if err == "timeout" then
                self.client = client -- in progress; writability below will settle it
                return
            end
            -- Refused: the host has not started listening yet. Try again next frame rather than
            -- treating a race between two hand-launched windows as a fatal error.
            client:close()
            self.retry = self.retry + 1
            self.error = "connecting (" .. tostring(err) .. ")"
            return
        end

        -- Writability is how a non-blocking connect announces it finished -- but a FAILED connect is
        -- writable too, so ask for the peer's name: that only answers once there really is one.
        local _, writable = socket.select(nil, { self.client }, 0)
        if writable and #writable > 0 then
            if self.client:getpeername() then
                self.state = "open"
            else
                self.client:close()
                self.client = nil -- start the attempt again
            end
        end
    end
end

function SocketTransport:send(message)
    if not self.client then return false end
    local payload = frame(message)
    local sent, err = self.client:send(payload)
    if not sent and err ~= "timeout" then
        self.state = "closed"
        self.error = "send failed: " .. tostring(err)
        return false
    end
    return true
end

-- Everything that has arrived since the last call, as whole messages. Partial frames stay in the
-- buffer until the rest of them turns up.
function SocketTransport:poll()
    self:advance()
    local out = {}
    if not self.client or self.state == "closed" then return out end

    while true do
        local data, err, partial = self.client:receive(4096)
        local chunk = data or partial
        if chunk and #chunk > 0 then
            self.inbuf = self.inbuf .. chunk
        end
        if err == "closed" then
            self.state = "closed"
            break
        end
        -- "timeout" is the ordinary answer for a non-blocking socket with nothing more to give.
        if not chunk or #chunk == 0 or err == "timeout" then break end
    end

    while #self.inbuf >= HEADER do
        local length = tonumber(self.inbuf:sub(1, HEADER))
        if not length then
            -- A frame header that is not a number means the stream is out of step, and every byte
            -- after it is suspect. Better to close than to hand the session invented messages.
            self.state = "closed"
            self.error = "corrupt frame header"
            break
        end
        if #self.inbuf < HEADER + length then break end -- the rest is still in flight
        out[#out + 1] = self.inbuf:sub(HEADER + 1, HEADER + length)
        self.inbuf = self.inbuf:sub(HEADER + length + 1)
    end
    return out
end

function SocketTransport:status()
    self:advance()
    return self.state
end

function SocketTransport:close()
    if self.client then self.client:close() end
    if self.server then self.server:close() end
    self.state = "closed"
end

return SocketTransport
