-- The guided-battle controller: the rules half of a scripted fight (data/tutorials/*.lua), driving
-- the prologue's village defense. It answers four questions for states/battle.lua, and nothing else:
--
--   * what should the bubble say right now          -> Tutorial.bubble
--   * is this action allowed                        -> Tutorial.allows / Tutorial.filterCells
--   * did the player just do the thing being asked  -> Tutorial.observe
--   * what does a scripted ally do on its turn      -> Tutorial.scriptFor
--
-- It holds no combat objects and touches no love.graphics, so the whole lesson is provable headless
-- (tests/tutorial_spec.lua) before a single frame is drawn. Liveness -- the one thing it cannot know
-- on its own -- arrives as a callback into Tutorial.reconcile rather than as a reference to the board.
--
-- The gate is deliberately expressed as a FILTER over cell sets, not as a veto on clicks. Narrowing
-- the sets states/battle.lua already builds means a disallowed tile is not a legal action anywhere:
-- highlight, cursor glyph, preview tooltip and click all agree with no per-path conditionals. See
-- the call sites in states/battle.lua (computeReachable / computeRange / computeThreat).

local Registry = require("models.registry")
local Conversation = require("models.conversation")
local Locale = require("models.locale")

local Tutorial = {}

Tutorial.defs = Registry.load("data/tutorials", "data.tutorials")

-- Every action kind a step may gate. `allows` answers for all of them, so a step that asks for a
-- move refuses a wait, an arm and a forfeit alike.
Tutorial.KINDS = { "move", "attack", "arm", "wait", "forfeit" }

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

-- Start a lesson. `cursors` tracks each scripted unit's place in its own queue; `abandoned` is the
-- escape hatch (see reconcile) that turns the whole gate off when the lesson can no longer be taught.
function Tutorial.new(id)
    local def = Tutorial.defs[id]
    if not def then return nil end
    return { id = id, def = def, index = 1, cursors = {}, abandoned = false }
end

function Tutorial.step(t)
    if not t or t.abandoned then return nil end
    return t.def.steps[t.index]
end

function Tutorial.done(t)
    return not t or t.abandoned or t.index > #t.def.steps
end

-- ---------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------

-- Find an authored line by its `id` in the tutorial's conversation. Conversation nodes may nest
-- inside conditional blocks, so this walks rather than indexes -- the tutorial authors flat scripts,
-- but a walk costs nothing and cannot be wrong if that changes.
local function nodeById(def, lineId)
    local conv = Conversation.defs[def.lines]
    if not (conv and lineId) then return nil end
    local function search(entries)
        for _, entry in ipairs(entries or {}) do
            if entry.script then
                local found = search(entry.script)
                if found then return found end
            elseif entry.id == lineId then
                return entry
            end
        end
    end
    return search(conv.script)
end

-- Resolve a line id to display text through the ordinary localization path, so a translated tutorial
-- needs no wiring of its own.
local function lineText(def, lineId)
    local node = nodeById(def, lineId)
    return node and Locale.text(def.lines, node) or nil
end

-- The NARRATIVE half: what the mentor says this instant, for her panel under the board. In-fiction
-- only -- it never names a mouse button or a tile colour. Nil once the lesson is done or abandoned,
-- which is also how the panel knows to disappear.
function Tutorial.narration(t)
    local step = Tutorial.step(t)
    if not step then return nil end
    local text = lineText(t.def, step.line)
    if not text then return nil end
    return { speaker = t.def.speaker, text = text }
end

-- The TECHNICAL half: the interface instruction and the thing it is pointing at. Drawn as a small
-- bubble pinned to that thing (states/battle.lua resolves the anchor to a rect), which is what lets
-- this half say "click" while the narration above stays in character. Nil when the step authored no
-- coaching -- a step may be pure fiction if the action is already obvious.
function Tutorial.coach(t)
    local step = Tutorial.step(t)
    if not step then return nil end
    local text = lineText(t.def, step.coach)
    if not text then return nil end
    return { text = text, anchor = step.anchor }
end

-- What to say when the player tries something the current step didn't ask for. Falls back to the
-- step's own line, so a step that authored no nudge still explains itself rather than going quiet.
function Tutorial.nudge(t)
    local step = Tutorial.step(t)
    if not step then return nil end
    return lineText(t.def, step.nudge) or lineText(t.def, step.line)
end

-- ---------------------------------------------------------------------------
-- Gating
-- ---------------------------------------------------------------------------

-- Which characters this lesson drives itself. states/battle.lua turns this into the unit's `control`
-- override, which Combat.new already honours on the party side (the escorted-ally path).
function Tutorial.controlFor(t, charId)
    if not t then return nil end
    for _, id in ipairs(t.def.scripted or {}) do
        if id == charId then return "ai" end
    end
    return nil
end

-- May the player take an action of this kind right now? Only the current step's kind, and everything
-- once the lesson is over or abandoned -- a finished tutorial must never leave the board locked.
function Tutorial.allows(t, kind)
    local step = Tutorial.step(t)
    if not step then return true end
    return step.gate.kind == kind
end

-- May this specific item be activated right now? A step that names an item admits only that one, so
-- "ready your sword" cannot be satisfied by arming the torch. A step that gates arming without
-- naming an item admits any; a step not about arming refuses everything (Tutorial.allows already
-- said so, and this agrees rather than contradicting it).
function Tutorial.allowsItem(t, itemId)
    local step = Tutorial.step(t)
    if not step then return true end
    if step.gate.kind ~= "arm" then return false end
    return step.gate.item == nil or step.gate.item == itemId
end

-- Does the current step want the player to arm something themselves? The battle normally arms a
-- unit's default action at the start of its turn; on an arm step it must not, or the lesson is
-- already satisfied before the player touches anything (and the click they are being asked for would
-- DISARM instead). See armDefaultAction in states/battle.lua.
function Tutorial.suppressesAutoArm(t)
    local step = Tutorial.step(t)
    return step ~= nil and step.gate.kind == "arm"
end

-- May the player act on cell (x, y) in one of the battle's sets? `kind` is "move" (the blue band) or
-- "attack" (the strike reach, armed or default). The two are not symmetric, because the lessons are
-- not:
--
--   * MOVE is only pinned by a step that is ABOUT moving. An attack step leaves the whole blue band
--     alone -- "strike the demon" has to let the player walk up to one, by whatever route they like.
--   * ATTACK is CLOSED outright unless the step asks for a strike. Otherwise a demon that wandered
--     into reach during the move or hold lesson would be swingable at, and the swing would spend the
--     turn without satisfying the step the player was actually on.
--
-- A step that asks for a strike but names no cells leaves the reach untouched: the target is pinned
-- by character id, and where it is approached from is the player's business.
--
-- Once the lesson is over or abandoned everything is permitted again. A finished tutorial that kept
-- refusing cells would leave the fight it opened unplayable.
function Tutorial.allowsCell(t, kind, x, y)
    local step = Tutorial.step(t)
    if not step then return true end
    local gate = step.gate
    if kind == "move" then
        if gate.kind ~= "move" then return true end
    elseif gate.kind ~= "attack" then
        return false
    end
    if not gate.cells then return true end
    for _, c in ipairs(gate.cells) do
        if c.x == x and c.y == y then return true end
    end
    return false
end

-- The list form of allowsCell, for the ordered cell lists the overlays draw from. Hands the input
-- back UNCHANGED once the lesson is over -- identity, not empty. Emptying sets a finished tutorial no
-- longer has an opinion about would black out the board with nothing to explain it
-- (tests/tutorial_spec.lua pins that case).
function Tutorial.filterCells(t, kind, cells)
    if Tutorial.done(t) then return cells end
    local kept = {}
    for _, c in ipairs(cells) do
        if Tutorial.allowsCell(t, kind, c.x, c.y) then kept[#kept + 1] = c end
    end
    return kept
end

-- ---------------------------------------------------------------------------
-- Progress
-- ---------------------------------------------------------------------------

-- Did `event` satisfy `step`? Every clause the step declared must match, and any it left out is
-- unconstrained -- so a strike step naming only a target accepts it from wherever the player chose to
-- approach. Events that don't match are simply ignored, which is what lets states/battle.lua report
-- every unit's every action here without filtering: enemy turns and Rowan's turns pour through
-- harmlessly.
local function satisfies(step, event)
    local gate = step.gate
    if gate.kind ~= event.kind then return false end
    if step.actor and step.actor ~= event.actor then return false end
    if gate.target and gate.target ~= event.target then return false end
    if gate.item and gate.item ~= event.item then return false end
    if gate.cells then
        local hit = false
        for _, c in ipairs(gate.cells) do
            if c.x == event.x and c.y == event.y then hit = true break end
        end
        if not hit then return false end
    end
    return true
end

-- Report a resolved action. Advances to the next step when it was the one being asked for.
function Tutorial.observe(t, event)
    local step = Tutorial.step(t)
    if not (step and event) then return end
    if satisfies(step, event) then t.index = t.index + 1 end
end

-- Pop the next authored turn for a scripted unit, or nil once its queue is dry (states/battle.lua
-- then falls back to the ordinary AI -- the lesson is over, and the fight still has to finish).
function Tutorial.scriptFor(t, charId)
    if not t or t.abandoned then return nil end
    local queue = t.def.script and t.def.script[charId]
    if not queue then return nil end
    local i = (t.cursors[charId] or 0) + 1
    t.cursors[charId] = i
    return queue[i]
end

-- Reconcile the lesson with a board that has moved on. `isAlive(charId)` answers whether any living
-- unit still carries that id. Two cases, both real:
--
--   * the step's TARGET is gone -- Rowan's own strike landed the kill, or a trap did. Skip the step;
--     asking the player to hit a corpse is worse than skipping the lesson.
--   * the step's ACTOR is gone -- the avatar died while Rowan still stands, so Combat.evaluate has
--     not called the fight yet. There is nobody left to teach: abandon, which unlocks every gate and
--     clears the bubble, and the tutorial degrades into an ordinary battle rather than a soft-lock.
function Tutorial.reconcile(t, isAlive)
    if not t or t.abandoned then return end
    while true do
        local step = t.def.steps[t.index]
        if not step then return end
        if step.actor and not isAlive(step.actor) then
            t.abandoned = true
            return
        end
        if step.gate.target and not isAlive(step.gate.target) then
            t.index = t.index + 1
        else
            return
        end
    end
end

return Tutorial
