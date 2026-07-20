-- A development harness for driving a duel between two windows on one machine.
--
-- DEVELOPMENT ONLY. Reached from the command line (`love . duel host` / `love . duel join`) and
-- gated on models/debug.lua; a shipped build matches through Steam and never comes here. The point
-- is to exercise the protocol against a real socket -- real serialization, real arrival timing, real
-- disconnects -- without needing two Steam accounts and two PCs to find out a turn was mis-sequenced.
--
-- What it deliberately is NOT is a second implementation of a battle. It builds the same combat both
-- peers build, applies commands through models/command.lua, and fingerprints with the same
-- state_hash the real thing will use. If this diverges from the game, the harness is wrong and worth
-- fixing, because the whole value of it is being the same code path.
--
-- On screen: both fingerprints, the turn number, whose turn it is, and the last few commands. That
-- readout IS the test -- two windows side by side, digests matching every turn.

local State = require("states")
local Scale = require("scale")
local Combat = require("models.combat")
local Command = require("models.command")
local Netplay = require("models.netplay")
local Transport = require("models.transport")
local StateHash = require("models.state_hash")
local Character = require("models.character")
local Item = require("models.item")

local duel = {}

local SEED = 4242 -- both peers must build the same board; hardcoded so the harness needs no lobby

local titleFont, bodyFont, monoFont

local function arena()
    local tiles = {}
    for y = 1, 8 do
        tiles[y] = {}
        for x = 1, 8 do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = 8, rows = 8, tiles = tiles, objective = { type = "killAll" }, seed = SEED }
end

local function fighter(id, x, y)
    local char = Character.instantiate(id)
    char.traits = {}
    char.inventory = {}
    Character.addItem(char, Item.instantiate("weapon_iron_sword"))
    return { char = char, x = x, y = y }
end

local function log(text)
    duel.lines[#duel.lines + 1] = text
    while #duel.lines > 12 do table.remove(duel.lines, 1) end
    print("[" .. tostring(duel.role) .. "] " .. text)
    -- And to a file, flushed every line. Two windows cannot both be watched at once, and a console
    -- redirected to a pipe buffers -- losing everything if the window is closed before it flushes,
    -- which is precisely when the interesting runs end.
    if duel.logFile then
        duel.logFile:write(text .. "\n")
        duel.logFile:flush()
    end
end

-- ---------------------------------------------------------------------------

function duel.enter(_, role, mode, port)
    titleFont = titleFont or love.graphics.newFont(24)
    bodyFont = bodyFont or love.graphics.newFont(16)
    monoFont = monoFont or love.graphics.newFont(14)

    -- One canonical role, so the command line's word ("join") and the transport's ("guest") cannot
    -- drift apart -- which they did, and cost an afternoon: both windows listened, and Windows
    -- happily let the second one bind the same port rather than refusing it.
    duel.isHost = (role == nil or role == "host")
    duel.role = duel.isHost and "host" or "guest"
    -- Self-play, so a full duel can be run and checked without a human at each window. It picks its
    -- own turns, but only ever for ITS OWN side -- the peers still have to agree about the result,
    -- which is the thing being tested.
    duel.auto = (mode == "auto")
    duel.autoTimer = 0
    duel.quitTimer = nil
    if io and io.stdout and io.stdout.setvbuf then io.stdout:setvbuf("no") end
    local dir = os.getenv("TEMP") or os.getenv("TMPDIR") or "."
    duel.logFile = io.open(dir .. "/lovetactics_duel_" .. duel.role .. ".log", "w")
    duel.lines = {}
    duel.turn = 0
    duel.status = "opening a socket..."

    -- The same board on both sides, from the same seed -- the thing the whole protocol assumes.
    duel.combat = Combat.new(arena(),
        { fighter("character_knight", 4, 8) }, { fighter("character_bandit", 4, 2) })
    -- Host drives the party, guest drives the enemy. Each machine only commands its own.
    duel.side = duel.isHost and "party" or "enemy"
    duel.combat.playerSide = duel.side

    log("starting as " .. duel.role .. " (drives " .. duel.side .. ")"
        .. (duel.auto and ", auto" or ""))

    local transport, why = Transport.open("localhost", { role = duel.role, port = port })
    if not transport then
        duel.status = "no transport: " .. tostring(why)
        log("no transport: " .. tostring(why))
        return
    end
    duel.transport = transport
    -- A transport that failed to open at all (a port already held by a stale process is the usual
    -- one) reports itself closed with a reason. Said out loud here: a window that silently sits on
    -- "waiting for the other" while the socket never opened is a miserable thing to diagnose.
    if transport.status and transport:status() == "closed" then
        log("transport failed: " .. tostring(transport.error))
        duel.status = "transport failed: " .. tostring(transport.error)
    end

    duel.session = Netplay.new({
        transport = transport,
        side = duel.side,
        seed = SEED,
        content = Netplay.contentFingerprint(),
        onReady = function(remote)
            duel.status = "connected -- they drive " .. tostring(remote.side)
            log("handshake agreed")
            Combat.startTurn(duel.combat)
        end,
        onCommand = function(cmd, n)
            -- A remote turn: apply it to our own model, exactly as they applied it to theirs.
            local unit = duel.combat.turn and duel.combat.turn.unit
            local res, err = Command.apply(duel.combat, unit, cmd)
            log(string.format("recv #%d %s -> %s", n, cmd.kind, res and "ok" or tostring(err)))
            duel.turn = n
            duel.session:report(n, duel.combat)
    log(string.format("  turn %d hash %s", n, StateHash.digestOf(duel.combat)))
            Combat.startTurn(duel.combat)
        end,
        onDesync = function(n, mine, theirs)
            duel.status = "DESYNC at turn " .. n
            log("mine   " .. mine)
            log("theirs " .. theirs)
        end,
        onClosed = function(reason)
            duel.status = "closed: " .. tostring(reason)
            log("closed: " .. tostring(reason))
        end,
    })
end

-- Is the unit currently up one of ours?
local function myTurn()
    local unit = duel.combat and duel.combat.turn and duel.combat.turn.unit
    return unit and unit.side == duel.side and duel.session and duel.session:isPlaying()
end

-- Take a turn locally, then tell the peer. Applied before sending on purpose: the local player sees
-- their own move happen without waiting for the network, which is the one latency advantage a
-- turn-based lockstep game gets for nothing.
local function take(cmd)
    if not myTurn() then return end
    local unit = duel.combat.turn.unit
    local res, err = Command.apply(duel.combat, unit, cmd)
    if not res then
        log("refused: " .. tostring(err))
        return
    end
    duel.session:submit(cmd)
    duel.turn = duel.session.turn
    log(string.format("sent #%d %s", duel.turn, cmd.kind))
    duel.session:report(duel.turn, duel.combat)
    log(string.format("  turn %d hash %s", duel.turn, StateHash.digestOf(duel.combat)))
    Combat.startTurn(duel.combat)
end

function duel.update(dt)
    if duel.session then duel.session:update() end
    if duel.transport and duel.transport.status and duel.session
        and duel.session.state == "handshake" then
        duel.status = duel.transport:status() == "open"
            and "connected -- shaking hands..."
            or ("waiting for the other window (" .. duel.role .. ")")
    end

    if duel.auto and myTurn() then
        duel.autoTimer = duel.autoTimer + dt
        if duel.autoTimer >= 0.35 then
            duel.autoTimer = 0
            -- Walk toward the far side while there is room, then wait. Nothing clever: the point is
            -- to generate real turns of both kinds and see whether the two boards still agree.
            local unit = duel.combat.turn.unit
            local dir = (unit.side == "party") and -1 or 1
            local ny = unit.y + dir
            if ny >= 1 and ny <= 8 and not Combat.unitAt(duel.combat, unit.x, ny) then
                take({ kind = "move", x = unit.x, y = ny })
            else
                take({ kind = "wait" })
            end
            if duel.turn >= 12 then
                log("auto: 12 turns done, stopping")
                duel.auto = false
                duel.quitTimer = 2 -- let the last hashes cross before closing
            end
        end
    end

    if duel.quitTimer then
        duel.quitTimer = duel.quitTimer - dt
        if duel.quitTimer <= 0 then
            local agreed, checked = 0, 0
            for n = 1, duel.turn do
                local mine, theirs = duel.session.myHashes[n], duel.session.theirHashes[n]
                if mine and theirs then
                    checked = checked + 1
                    if mine == theirs then agreed = agreed + 1 end
                end
            end
            log(string.format("RESULT %d/%d turns compared agreed", agreed, checked))
            if duel.session then duel.session:close("auto run finished") end
            love.event.quit(0)
        end
    end
end

function duel.draw()
    love.graphics.clear(0.09, 0.09, 0.12)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.95, 0.85, 0.55)
    love.graphics.printf("Duel harness -- " .. duel.role .. " (" .. tostring(duel.side) .. ")",
        0, 24, Scale.WIDTH, "center")

    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.8, 0.82, 0.9)
    love.graphics.printf(duel.status or "", 0, 60, Scale.WIDTH, "center")

    -- The readout that IS the test: both fingerprints, side by side, every turn.
    local mine = duel.combat and StateHash.digestOf(duel.combat) or "-"
    local theirs = duel.session and duel.session.theirHashes[duel.turn] or "-"
    local agree = (theirs ~= "-" and mine == theirs)
    love.graphics.setFont(monoFont)
    love.graphics.setColor(0.7, 0.75, 0.85)
    love.graphics.printf("turn " .. tostring(duel.turn), 0, 96, Scale.WIDTH, "center")
    love.graphics.printf("mine   " .. mine, 0, 116, Scale.WIDTH, "center")
    love.graphics.printf("theirs " .. tostring(theirs), 0, 134, Scale.WIDTH, "center")
    if theirs ~= "-" then
        love.graphics.setColor(agree and 0.5 or 0.9, agree and 0.9 or 0.4, agree and 0.55 or 0.4)
        love.graphics.printf(agree and "AGREED" or "DISAGREE", 0, 156, Scale.WIDTH, "center")
    end

    -- The board, plainly.
    local ox, oy, size = Scale.WIDTH / 2 - 8 * 32 / 2, 190, 32
    for y = 1, 8 do
        for x = 1, 8 do
            love.graphics.setColor(0.16, 0.17, 0.21)
            love.graphics.rectangle("line", ox + (x - 1) * size, oy + (y - 1) * size, size, size)
        end
    end
    for _, u in ipairs(duel.combat and duel.combat.units or {}) do
        if u.alive then
            local isMine = u.side == duel.side
            love.graphics.setColor(isMine and 0.45 or 0.85, isMine and 0.75 or 0.4, isMine and 0.95 or 0.4)
            love.graphics.rectangle("fill", ox + (u.x - 1) * size + 4, oy + (u.y - 1) * size + 4,
                size - 8, size - 8, 4, 4)
        end
    end

    local up = duel.combat and duel.combat.turn and duel.combat.turn.unit
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(myTurn() and 0.6 or 0.45, myTurn() and 0.9 or 0.45, 0.6)
    love.graphics.printf(myTurn() and "YOUR TURN -- arrows move, space waits"
        or ("waiting on " .. (up and up.side or "?")), 0, oy + 8 * size + 12, Scale.WIDTH, "center")

    love.graphics.setFont(monoFont)
    love.graphics.setColor(0.55, 0.58, 0.66)
    for i, line in ipairs(duel.lines) do
        love.graphics.print(line, 24, oy + 8 * size + 44 + (i - 1) * 17)
    end

    love.graphics.setColor(1, 1, 1)
end

function duel.keypressed(key)
    if key == "escape" then
        if duel.session then duel.session:close("quit") end
        if duel.transport then duel.transport:close() end
        love.event.quit(0)
        return
    end
    if not myTurn() then return end
    local unit = duel.combat.turn.unit
    local dirs = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
    if dirs[key] then
        take({ kind = "move", x = unit.x + dirs[key][1], y = unit.y + dirs[key][2] })
    elseif key == "space" or key == "tab" then
        take({ kind = "wait" })
    end
end

return duel
