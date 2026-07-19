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
    return { id = id, def = def, index = 1, cursors = {}, spawned = {}, abandoned = false }
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
    -- Split rather than read whole: a coaching line opens with the `{select}` token, and the bubble
    -- draws that as a KEY CAP instead of writing a verb for it (see Locale.coachLine). `key` is nil
    -- for a line that names no button, and the bubble then lays out as words alone.
    local node = nodeById(t.def, step.coach)
    if not node then return nil end
    local text, key = Locale.coachLine(t.def.lines, node)
    if not text or text == "" then return nil end
    return { text = text, key = key, anchor = step.anchor }
end

-- The item id this step hands the player, or nil. A lesson may need something the player does not
-- own yet -- the prologue's mentor passes over her Clear Out mid-fight, because an ability lesson is
-- unteachable to someone carrying only a sword.
--
-- Deliberately states only WHAT is given, never whether it has landed: states/battle.lua owns
-- inventories, applies this idempotently (it checks the grid first), and can therefore ask every
-- frame. So the gift arrives the instant the step becomes current, no matter which path advanced to
-- it, and re-entering the step can never duplicate it.
function Tutorial.grant(t)
    local step = Tutorial.step(t)
    return step and step.grant or nil
end

-- Should the board hide its DANGER paint during this step? The battle normally washes every tile a
-- foe could reach-and-strike -- purple over your own move band, and a red line traced back from each
-- threatening body to the tile under the cursor. It is one of the most useful things it draws, and
-- it is also the wrong first thing to see: on the opening step the player is being taught what a
-- click does, and a board already speaking in three colours about a threat model they have not been
-- told about yet reads as noise. So the first lesson turns it off and shows exactly two things --
-- where to stand, and what to hit. Everything after it paints normally, by which point the colours
-- have something to say.
function Tutorial.hidesDanger(t)
    local step = Tutorial.step(t)
    return step ~= nil and step.calm == true
end

-- The conversation this lesson opens with, played over the board before any turn resolves -- or nil
-- for a lesson that starts swinging. A property of the whole lesson rather than of a step, because
-- it runs BEFORE step 1 is anybody's business: the board is up, nobody has acted, and the scene is
-- what turns a fight that starts into a fight that is introduced.
function Tutorial.opening(t)
    return t and not t.abandoned and t.def.opening or nil
end

-- The reinforcements this step walks onto the board, as a list of { char, x, y } -- or nil. Claimed
-- ONCE per step (unlike Tutorial.grant, which is idempotent by inspection): a spawned unit can die,
-- so "is it already there?" is not a question the caller can answer, and the lesson has to remember
-- instead. states/battle.lua turns each entry into a Combat.addUnit.
--
-- A lesson needs this for a reason worth stating: a fight whose enemies all die at the end of the
-- teaching has no middle. Walking a fresh body on mid-lesson is what lets the last thing taught be
-- used in earnest rather than demonstrated into an empty field.
-- Does the lesson still owe this fight a body? True while the current step declares reinforcements
-- that have not walked on yet.
--
-- states/battle.lua holds the VICTORY open on this, and that is the whole reason it is a separate
-- question from claimSpawn. The village lesson's Clear Out kills the last two imps, and an empty enemy
-- side is a win (Combat.evaluate) -- so without this the battle would end a beat before the
-- reinforcement the remaining three steps are entirely about. A lesson that has more to field is a
-- fight that is not over, and only the lesson knows that.
function Tutorial.awaitsSpawn(t)
    local step = Tutorial.step(t)
    return step ~= nil and step.spawn ~= nil and not t.spawned[t.index]
end

function Tutorial.claimSpawn(t)
    if not Tutorial.awaitsSpawn(t) then return nil end
    t.spawned[t.index] = true
    return Tutorial.step(t).spawn
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
-- The one exception to the first rule is `gate.approach`: the tiles this step will let the player
-- stand on. It exists because a step reached with an UNSPENT move is a trap otherwise -- the player
-- walks off, then owes an action on something they can no longer reach, with every other action
-- refused by the gate and no way to end the turn. Two shapes, and the lesson uses both:
--
--   approach = { {x,y}, ... }  -- only these tiles. Step 1 names the single square its target can be
--                                 struck from, which closes the trap AND teaches something: every
--                                 tile the blue band offers is one the blow can be thrown from, so
--                                 "get next to it" is shown rather than described.
--   approach = {}              -- no tiles at all: stand still. For a step that opens a fresh turn
--                                 already standing where it needs to be, where any step is a step
--                                 out of range and there was never a good one to take.
--
-- A step that declares neither leaves the band alone, which is right for one reached mid-turn: the
-- move is already spent, so there is nothing to pin.
--
-- Once the lesson is over or abandoned everything is permitted again. A finished tutorial that kept
-- refusing cells would leave the fight it opened unplayable.
function Tutorial.allowsCell(t, kind, x, y)
    local step = Tutorial.step(t)
    if not step then return true end
    local gate = step.gate
    if kind == "move" then
        if gate.approach then
            for _, c in ipairs(gate.approach) do
                if c.x == x and c.y == y then return true end
            end
            return false
        end
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
--
-- `key` is the unit's SCRIPT KEY, not simply its blueprint id: states/battle.lua keys a party member
-- by character id (unique within a party) and an enemy by the cell it spawned on. Enemies need the
-- second form because a lesson may field several of one blueprint -- three identical imps share an
-- id, and a queue keyed by it would be popped by whichever happened to act first.
--
-- Goes quiet the moment the lesson is DONE, not just when a queue runs dry. A script exists to hold
-- the board still while something is being taught; once nothing is, a scripted ally standing at
-- attention through the rest of the fight would be worse than no script at all -- so the mentor is
-- handed back to the ordinary AI and joins in. Same principle as the gates: nothing the lesson
-- imposed may outlive it.
function Tutorial.scriptFor(t, key)
    if not t or Tutorial.done(t) then return nil end
    local queue = t.def.script and t.def.script[key]
    if not queue then return nil end
    local i = (t.cursors[key] or 0) + 1
    t.cursors[key] = i
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
