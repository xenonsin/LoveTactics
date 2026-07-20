-- A duel session: the protocol two peers speak over a transport.
--
-- Transport-agnostic by construction -- it is handed something with send/poll/status and never asks
-- what is underneath (models/transport.lua). That is what lets the whole protocol be tested on a
-- loopback pair in the headless suite, and why Steam is a transport rather than a rewrite.
--
-- WHAT TRAVELS. Four message kinds, all plain data through save.lua's encoder:
--
--   hello  { version, content, side, seed, roster }  -- once, before anything starts
--   cmd    { n, cmd }                                -- one turn's intent
--   hash   { n, digest }                             -- what my board looked like after turn n
--   bye    { reason }                                -- forfeit, quit, or a desync being announced
--
-- THE SHAPE OF A TURN. Exactly one peer owns any given turn -- the one whose unit the timeline put
-- up -- so there is no simultaneity to resolve and no rollback. That peer applies its command
-- locally, sends it, and the other applies the same command on arrival. Then BOTH send a digest for
-- that turn number and compare. Turns are seconds apart, so hashing every one costs nothing and a
-- desync is caught on the turn that caused it, when the command that did it is still named.
--
-- WHY THE HANDSHAKE REFUSES RATHER THAN ADAPTS. A duel between two different versions of the game,
-- or two different sets of content, is not a duel that can be repaired mid-fight -- the two are
-- computing different rules. Refusing to start with a clear message is the only honest outcome, and
-- catching it at handshake means it is never mistaken later for a mysterious turn-12 desync.
--
-- Pure model: no love.*, so it runs headless.

local Save = require("models.save")
local Command = require("models.command")
local StateHash = require("models.state_hash")

local Netplay = {}
Netplay.__index = Netplay

-- Bumped when the protocol changes shape. Peers refuse each other across a mismatch.
Netplay.VERSION = 1

Netplay.STATE = { handshake = "handshake", playing = "playing", over = "over", desynced = "desynced" }

-- ---------------------------------------------------------------------------
-- Wire
-- ---------------------------------------------------------------------------

local function encode(msg)
    return "return " .. Save.encode(msg, 0)
end

local function decode(source)
    local ok, msg = pcall(Save.decode, source)
    if not ok then return nil end
    return msg
end

-- ---------------------------------------------------------------------------
-- Session
-- ---------------------------------------------------------------------------

-- opts = {
--   transport,           -- send/poll/status
--   side      = "party", -- which side this machine drives
--   seed, content,       -- the board's seed and a fingerprint of the loaded content
--   roster    = <build snapshot of my team>,
--   onReady   = function(remote) end,          -- handshake agreed; remote is their hello
--   onCommand = function(cmd, n) end,          -- a remote turn to apply locally
--   onDesync  = function(n, mine, theirs) end, -- boards disagreed after turn n
--   onClosed  = function(reason) end,
-- }
function Netplay.new(opts)
    local self = setmetatable({}, Netplay)
    self.transport = opts.transport
    self.side = opts.side
    self.seed = opts.seed
    self.content = opts.content
    self.roster = opts.roster
    self.onReady = opts.onReady
    self.onCommand = opts.onCommand
    self.onDesync = opts.onDesync
    self.onClosed = opts.onClosed

    self.state = Netplay.STATE.handshake
    self.turn = 0             -- turns completed
    self.myHashes = {}        -- n -> digest I computed
    self.theirHashes = {}     -- n -> digest they reported
    self.pending = {}         -- remote commands arrived but not yet applied
    self.remote = nil         -- their hello

    -- The hello is NOT sent here. A transport may still be connecting -- a socket has no peer to
    -- write to until the other window turns up -- and a hello sent into that goes nowhere, with both
    -- peers then waiting forever on a message neither ever sent. It goes out from update(), once,
    -- the first time the link reports itself open.
    --
    -- (A loopback pair is open from the instant it exists, which is exactly why this was missed
    -- until a real socket was involved.)
    self.helloSent = false
    return self
end

-- Send the opening hello if the link is ready and it has not gone yet.
function Netplay:greet()
    if self.helloSent then return end
    if not self.transport or self.transport:status() ~= "open" then return end
    self.helloSent = true
    self:say({ t = "hello", version = Netplay.VERSION, content = self.content,
               side = self.side, seed = self.seed, roster = self.roster })
end

function Netplay:say(msg)
    if self.transport then self.transport:send(encode(msg)) end
end

function Netplay:close(reason)
    if self.state == Netplay.STATE.over then return end
    self:say({ t = "bye", reason = reason })
    self.state = Netplay.STATE.over
    if self.onClosed then self.onClosed(reason) end
end

-- Their hello against mine. Returns nil when they agree, or the reason they cannot play together.
function Netplay:disagreement(hello)
    if hello.version ~= Netplay.VERSION then
        return "different game versions (protocol " .. tostring(hello.version)
            .. " vs " .. Netplay.VERSION .. ")"
    end
    if self.content and hello.content and hello.content ~= self.content then
        return "different content -- one of you has mods or a different patch"
    end
    if self.seed and hello.seed and hello.seed ~= self.seed then
        return "different boards (seed " .. tostring(hello.seed) .. " vs " .. tostring(self.seed) .. ")"
    end
    if hello.side == self.side then
        return "both peers tried to drive the " .. tostring(self.side) .. " side"
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------

-- Announce the turn this peer just took. The command has ALREADY been applied locally -- the local
-- player saw their own move happen without waiting for the network, which is the one latency
-- advantage a turn-based lockstep game gets for free.
function Netplay:submit(cmd)
    if self.state ~= Netplay.STATE.playing then return false, "not playing" end
    self.turn = self.turn + 1
    self:say({ t = "cmd", n = self.turn, cmd = cmd })
    return true
end

-- Report what my board looks like after turn `n`, and compare if theirs has already arrived.
function Netplay:report(n, combat)
    local digest = StateHash.digestOf(combat)
    self.myHashes[n] = digest
    self:say({ t = "hash", n = n, digest = digest })
    self:compare(n)
end

function Netplay:compare(n)
    local mine, theirs = self.myHashes[n], self.theirHashes[n]
    if not (mine and theirs) then return end
    if mine == theirs then return end
    -- No attempt to resynchronize. There is no state serializer -- that is the whole premise of
    -- lockstep -- so there is nothing to resync TO, and a game that quietly plays on is two people
    -- in two different fights believing they are in one.
    self.state = Netplay.STATE.desynced
    if self.onDesync then self.onDesync(n, mine, theirs) end
    self:say({ t = "bye", reason = "desync at turn " .. n })
end

-- ---------------------------------------------------------------------------
-- Receiving
-- ---------------------------------------------------------------------------

function Netplay:handle(msg)
    if type(msg) ~= "table" or not msg.t then return end

    if msg.t == "hello" then
        self.remote = msg
        local why = self:disagreement(msg)
        if why then
            self.state = Netplay.STATE.over
            self:say({ t = "bye", reason = why })
            if self.onClosed then self.onClosed(why) end
            return
        end
        self.state = Netplay.STATE.playing
        if self.onReady then self.onReady(msg) end

    elseif msg.t == "cmd" then
        -- Queued rather than applied here: the caller owns the model and applies it when it is ready
        -- to (and can animate it), which keeps this module free of any opinion about the view.
        self.pending[#self.pending + 1] = { n = msg.n, cmd = msg.cmd }

    elseif msg.t == "hash" then
        self.theirHashes[msg.n] = msg.digest
        self:compare(msg.n)

    elseif msg.t == "bye" then
        self.state = (self.state == Netplay.STATE.desynced) and self.state or Netplay.STATE.over
        if self.onClosed then self.onClosed(msg.reason) end
    end
end

-- Drain the transport. Call once a frame.
function Netplay:update()
    if not self.transport then return end
    self:greet()
    for _, source in ipairs(self.transport:poll()) do
        local msg = decode(source)
        if msg then self:handle(msg) end
    end

    -- Hand over any remote turns that are ready, in order.
    while #self.pending > 0 and self.state == Netplay.STATE.playing do
        local entry = table.remove(self.pending, 1)
        self.turn = math.max(self.turn, entry.n)
        if self.onCommand then self.onCommand(entry.cmd, entry.n) end
    end

    if self.transport:status() == "closed" and self.state == Netplay.STATE.playing then
        self.state = Netplay.STATE.over
        if self.onClosed then self.onClosed("connection lost") end
    end
end

function Netplay:isPlaying() return self.state == Netplay.STATE.playing end
function Netplay:isDesynced() return self.state == Netplay.STATE.desynced end

-- A fingerprint of the loaded content, so two peers can tell they are playing the same game before
-- they discover it the hard way. Sorted ids of everything the rules read -- a mod or a patch that
-- adds, removes or renames content moves it.
function Netplay.contentFingerprint()
    local parts = {}
    for _, mod in ipairs({ "models.character", "models.item", "models.status", "models.trait" }) do
        local ok, m = pcall(require, mod)
        if ok and m and m.defs then
            local ids = {}
            for id in pairs(m.defs) do ids[#ids + 1] = tostring(id) end
            table.sort(ids)
            parts[#parts + 1] = mod .. ":" .. table.concat(ids, ",")
        end
    end
    return StateHash.digest(table.concat(parts, "|"))
end

return Netplay
