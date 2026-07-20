-- What one duellist tells the other they did.
--
-- A whole turn reduces to one of five things, and this is the only vocabulary that travels between
-- peers. Lockstep does not ship state -- it ships INTENT, and both machines resolve it themselves.
-- Everything the model needs to reproduce a turn exactly has to fit in here, and nothing that could
-- differ between two machines may.
--
--   { kind = "move",    x, y, path = { {x,y}, ... } }   -- path optional: a steered route
--   { kind = "use",     cell, tx, ty }                  -- cell is an INVENTORY SLOT, not an item id
--   { kind = "wait" }
--   { kind = "blink",   x, y }
--   { kind = "forfeit" }
--
-- The item is named by grid cell rather than by id on purpose. Ids are ambiguous -- a character can
-- carry two of the same blueprint at different upgrade levels -- and the cell is what the player
-- actually clicked. It is also stable: both peers rebuilt the same character from the same snapshot,
-- so cell 4 holds the same thing on both boards.
--
-- VALIDATION IS A TRUST BOUNDARY. A command arriving from the network is checked before it is
-- applied, against the same rules the local player's input goes through -- not because the opponent
-- is assumed hostile (lockstep cannot defend against a modified client anyway; see the plan), but
-- because a command that is merely STALE -- sent against a board that has since moved on -- would
-- otherwise desync both peers instead of being refused by one.
--
-- Pure model: no love.*, so it loads headless.

local Combat = require("models.combat")
local Character = require("models.character")

local Command = {}

Command.KINDS = { move = true, use = true, wait = true, blink = true, forfeit = true }

-- ---------------------------------------------------------------------------
-- Shape
-- ---------------------------------------------------------------------------

local function isCell(v)
    return type(v) == "number" and v == math.floor(v) and v >= 1 and v <= Character.MAX_INVENTORY
end

local function isCoord(v)
    return type(v) == "number" and v == math.floor(v)
end

-- Is this a well-formed command at all, before asking whether it is a LEGAL one? Separated because
-- the two failures want different answers: malformed means the peer is broken or the message was
-- corrupted, illegal means the boards disagree.
function Command.wellFormed(cmd)
    if type(cmd) ~= "table" then return false, "not a command" end
    if not Command.KINDS[cmd.kind] then return false, "unknown kind " .. tostring(cmd.kind) end

    if cmd.kind == "move" or cmd.kind == "blink" then
        if not (isCoord(cmd.x) and isCoord(cmd.y)) then return false, cmd.kind .. " needs whole x,y" end
        if cmd.path ~= nil then
            if type(cmd.path) ~= "table" then return false, "path must be a list" end
            for i, c in ipairs(cmd.path) do
                if not (type(c) == "table" and isCoord(c.x) and isCoord(c.y)) then
                    return false, "path step " .. i .. " is not a cell"
                end
            end
        end
    elseif cmd.kind == "use" then
        if not isCell(cmd.cell) then return false, "use needs an inventory cell 1.." .. Character.MAX_INVENTORY end
        if not (isCoord(cmd.tx) and isCoord(cmd.ty)) then return false, "use needs whole tx,ty" end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Legality
-- ---------------------------------------------------------------------------

-- The item a `use` command names, or nil plus a reason.
function Command.itemFor(unit, cmd)
    local item = unit.char and unit.char.inventory and unit.char.inventory[cmd.cell]
    if not item then return nil, "nothing in cell " .. tostring(cmd.cell) end
    local blocked = Combat.itemBlockReason(unit, item)
    if blocked then return nil, blocked end
    return item
end

-- May `unit` do this, on this board, right now? Returns true, or false plus a reason.
--
-- Deliberately does NOT mutate: every check below either reads state or asks the model to PLAN
-- something (planMove returns a plan and changes nothing). A validator with a side effect would be
-- worse than none, because the peer that rejected a command would already have half-applied it.
function Command.validate(combat, unit, cmd)
    local ok, why = Command.wellFormed(cmd)
    if not ok then return false, why end

    if not unit then return false, "no unit" end
    if not unit.alive then return false, "unit is down" end
    if not combat.turn or combat.turn.unit ~= unit then return false, "not this unit's turn" end

    if cmd.kind == "forfeit" or cmd.kind == "wait" then
        return true
    elseif cmd.kind == "move" then
        if combat.turn.moved then return false, "already moved" end
        local plan = cmd.path and Combat.planMoveVia(combat, unit, cmd.path)
        if not plan then
            local reason
            plan, reason = Combat.planMove(combat, unit, cmd.x, cmd.y)
            if not plan then return false, reason or "unreachable" end
        end
        -- A steered route must actually end where the command says it does, or the two peers would
        -- walk the same path to different tiles.
        local last = plan.path[#plan.path]
        if last.x ~= cmd.x or last.y ~= cmd.y then return false, "route does not end at the target" end
        return true
    elseif cmd.kind == "blink" then
        return true -- Combat.blink is its own gate (mana, range, footing) and answers on apply
    elseif cmd.kind == "use" then
        local item, reason = Command.itemFor(unit, cmd)
        if not item then return false, reason end
        return true
    end
    return false, "unhandled kind " .. tostring(cmd.kind)
end

-- ---------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------

-- Resolve `cmd` against the model. Returns a result table, or nil plus a reason if it was refused.
--
--   { moved = <route steps or nil>, acted = <bool>, forfeited = <bool> }
--
-- `moved` is the captured route from Combat.runMove, so a caller with a view can replay the walk at
-- a walking pace while the model has already finished it (see states/battle.lua). A headless caller
-- ignores it and the state is identical either way -- which is precisely the property that lets one
-- peer animate a turn and the other's spec not.
function Command.apply(combat, unit, cmd)
    local ok, why = Command.validate(combat, unit, cmd)
    if not ok then return nil, why end

    local result = { moved = nil, acted = false, forfeited = false }

    if cmd.kind == "forfeit" then
        result.forfeited = true
        return result
    end

    if cmd.kind == "wait" then
        local kind = Combat.waitBehavior(unit).kind
        local action = (kind == "focus" and Combat.focus)
            or (kind == "defend" and Combat.defend)
            or (kind == "overwatch" and Combat.overwatch)
            or Combat.wait
        result.acted = action(combat, unit) and true or false
        return result
    end

    if cmd.kind == "blink" then
        result.acted = Combat.blink(combat, unit, cmd.x, cmd.y) and true or false
        if not result.acted then return nil, "blink refused" end
        return result
    end

    if cmd.kind == "move" then
        local plan = cmd.path and Combat.planMoveVia(combat, unit, cmd.path)
            or Combat.planMove(combat, unit, cmd.x, cmd.y)
        if not plan then return nil, "unreachable" end
        result.moved = Combat.runMove(combat, plan)
        return result
    end

    -- use: walk first when the command carries a route, then act from where it left off -- the same
    -- order states/battle.lua resolves an approach-and-strike in, so both produce one state.
    if cmd.kind == "use" then
        if cmd.path or cmd.x then
            local plan = cmd.path and Combat.planMoveVia(combat, unit, cmd.path)
                or (cmd.x and Combat.planMove(combat, unit, cmd.x, cmd.y))
            if plan then result.moved = Combat.runMove(combat, plan) end
        end
        if not unit.alive then return result end -- cut down on the approach
        local item, reason = Command.itemFor(unit, cmd)
        if not item then return nil, reason end
        result.acted = Combat.useItem(combat, unit, item, cmd.tx, cmd.ty) and true or false
        if not result.acted then
            -- The turn still has to end, or a peer would sit forever on a unit that did nothing.
            Combat.pass(combat, unit)
        end
        return result
    end

    return nil, "unhandled kind"
end

return Command
