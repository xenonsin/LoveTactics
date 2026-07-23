-- Tests the guided-battle controller (models/tutorial.lua) and the board its lesson is authored
-- against (data/arenas/tutorial_village.lua). The whole tutorial is provable here: the controller
-- holds no combat objects and no love.graphics, so every rule can be checked without a battle.
--
-- Two of these are regression guards rather than feature tests, and matter more than the rest:
-- the `fixed` exclusion (a scripted map must never be rolled by an ordinary forest fight) and
-- filterCells' identity case (narrowing a set the step never meant to touch would black out the
-- board). Both are named where they appear.

local Tutorial = require("models.tutorial")
local Conversation = require("models.conversation")
local Arena = require("models.arena")
local Item = require("models.item")
local Character = require("models.character")
local Combat = require("models.combat")

local TUTORIAL = "village"
local ARENA = "tutorial_village"

-- Every cell of an 8x8 board -- the unfiltered input filterCells is asked to narrow.
local function allCells()
    local cells = {}
    for y = 1, 8 do
        for x = 1, 8 do cells[#cells + 1] = { x = x, y = y } end
    end
    return cells
end

local function key(c) return c.x .. "," .. c.y end

-- Advance a fresh tutorial to step `n` by feeding it the action each earlier step asked for.
-- The event a step is waiting for -- every clause it declared, filled in from the step itself.
local function satisfyingEvent(step)
    local cell = step.gate.cells and step.gate.cells[1] or {}
    return { kind = step.gate.kind, actor = step.actor, target = step.gate.target,
             item = step.gate.item, x = cell.x, y = cell.y }
end

local function atStep(n)
    local t = Tutorial.new(TUTORIAL)
    for _ = 2, n do
        Tutorial.observe(t, satisfyingEvent(Tutorial.step(t)))
    end
    return t
end

-- ---------------------------------------------------------------------------
-- Playing the lesson for real
-- ---------------------------------------------------------------------------
--
-- Everything below drives the village fight the way states/battle.lua drives it -- real arena, real
-- Combat, real initiative -- rather than reading the lesson data and trusting it.
--
-- That distinction is the whole point. The two failures this exists to catch were both invisible to
-- every check that read one file at a time: the mentor lost the opening turn to a tie-break in
-- models/combat.lua, and her standing guard was spent one turn early on an empty board, leaving the
-- third imp alive at her elbow for the rest of the fight. Neither is a fact about the lesson or about
-- combat -- each lives in the seam between them, and only a played turn order shows it.
--
-- The animation is the only thing dropped: a walk resolves in a loop instead of a tile per frame.

local function livingById(combat, charId)
    for _, u in ipairs(combat.units) do
        if u.alive and u.char.id == charId then return u end
    end
    return nil
end

local function heldItem(char, itemId)
    for _, item in ipairs(Character.eachItem(char)) do
        if item.id == itemId then return item end
    end
    return nil
end

local function walkTo(combat, unit, x, y)
    if unit.x == x and unit.y == y then return true end
    local plan = Combat.planMove(combat, unit, x, y)
    if not plan then return false end
    local walk = Combat.beginMove(combat, plan)
    while Combat.stepMove(combat, walk) do end
    return unit.x == x and unit.y == y
end

-- states/battle.lua's scriptedAction and executeEnemyAction, collapsed: pop the unit's authored turn,
-- walk it, and swing if the entry names a living foe (or, for a post, if one is at its elbow).
local function runScripted(combat, t, unit)
    local entry = Tutorial.scriptFor(t, unit.scriptKey or unit.char.id)
    if not entry then Combat.pass(combat, unit) return end
    if entry.move then walkTo(combat, unit, entry.move.x, entry.move.y) end
    local tx, ty
    if entry.strike then
        local foe = Combat.unitAt(combat, entry.strike.x, entry.strike.y)
        if foe and foe.side ~= unit.side then tx, ty = entry.strike.x, entry.strike.y end
    elseif entry.guard then
        for _, other in ipairs(combat.units) do
            if other.alive and other.side ~= unit.side
                and math.abs(other.x - unit.x) + math.abs(other.y - unit.y) == 1 then
                tx, ty = other.x, other.y
                break
            end
        end
    end
    if tx and Combat.useItem(combat, unit, Combat.defaultWeapon(unit.char), tx, ty) then return end
    Combat.pass(combat, unit)
end

-- The player's turn, played as the lesson's own happy path: do exactly what the current step asks
-- for, and keep going while the next step is still part of this turn (a move and an arm end nothing;
-- a strike does).
local function runPlayer(combat, t, unit, stopAt, refusals)
    while true do
        local step = Tutorial.step(t)
        if not step or t.index >= stopAt then break end
        -- The gift lands the instant its step becomes current (grantLessonItem), which is mid-turn
        -- for the Clear Out -- so it is applied here rather than once per turn.
        local gift = Tutorial.grant(t)
        if gift and not heldItem(unit.char, gift) then
            Character.addItem(unit.char, Item.instantiate(gift))
        end
        local gate = step.gate
        if gate.kind == "move" then
            local cell = gate.cells[1]
            assert(walkTo(combat, unit, cell.x, cell.y),
                "the lesson's move step names a tile the avatar cannot reach: "
                .. cell.x .. "," .. cell.y)
            Tutorial.observe(t, { kind = "move", actor = unit.char.id, x = cell.x, y = cell.y })
        elseif gate.kind == "arm" then
            Tutorial.observe(t, { kind = "arm", actor = unit.char.id, item = gate.item })
        elseif gate.kind == "attack" then
            if gate.approach and gate.approach[1] then
                local cell = gate.approach[1]
                assert(walkTo(combat, unit, cell.x, cell.y),
                    "the lesson's approach tile is unreachable: " .. cell.x .. "," .. cell.y)
            end
            local tx, ty
            if gate.cells then
                tx, ty = gate.cells[1].x, gate.cells[1].y
            else
                local foe = livingById(combat, gate.target)
                assert(foe, "the lesson asks for a strike on a body that is not on the board: "
                    .. tostring(gate.target))
                tx, ty = foe.x, foe.y
            end
            local item = heldItem(unit.char, gate.item)
            assert(item, "the avatar does not hold what the lesson asks them to swing: "
                .. tostring(gate.item))
            -- A refused strike is recorded rather than raised: it is almost always a SYMPTOM of the
            -- fight having drifted out of its authored order (a body standing somewhere the step did
            -- not put it), and the order assertion downstream names that far more usefully than an
            -- abort here would.
            if not Combat.useItem(combat, unit, item, tx, ty) then
                refusals[#refusals + 1] = gate.item .. " at step " .. t.index
                break
            end
            Tutorial.observe(t, { kind = "attack", actor = unit.char.id, target = gate.target,
                                  item = gate.item, x = tx, y = ty })
            break -- a strike ends the turn
        else
            break -- wait/forfeit: not on the village's happy path
        end
    end
    if combat.turn and combat.turn.unit == unit and unit.alive then Combat.pass(combat, unit) end
end

-- Build the fight exactly as states/battle.lua's enter does, then play it until step `stopAt` is the
-- current one. Returns the lesson and the board, for the caller to make assertions about.
local function playVillage(stopAt)
    local t = Tutorial.new(TUTORIAL)
    local arena = Arena.build({ prestige = 1, biome = "forest" },
        { layout = ARENA, biome = "forest",
          party = { "character_avatar", "character_knight" },
          composition = function()
              return { "character_demon_imp", "character_demon_imp", "character_demon_imp",
                       "character_demon_imp", "character_demon_imp" }
          end })
    local party, enemies = {}, {}
    for _, u in ipairs(arena.party) do
        party[#party + 1] = { char = Character.instantiate(u.id), x = u.x, y = u.y,
                              control = Tutorial.controlFor(t, u.id) }
    end
    for _, u in ipairs(arena.enemies) do
        enemies[#enemies + 1] = { char = Character.instantiate(u.id), x = u.x, y = u.y }
    end
    local combat = Combat.new(arena, party, enemies)
    for _, u in ipairs(combat.units) do
        u.scriptKey = (u.side == "party") and u.char.id or (u.x .. "," .. u.y)
    end
    -- The lesson's authored seating, applied as states/battle.lua applies it.
    if Tutorial.paces(t) then
        for _, u in ipairs(combat.units) do
            u.initiative = Tutorial.startInitiative(t, u.scriptKey)
        end
        Combat.rebase(combat)
    end

    local isAlive = function(charId) return livingById(combat, charId) ~= nil end
    local order = {}    -- the sequence of turns actually taken, for the caller to pin
    local refusals = {} -- steps whose own action the board would not accept
    -- Bounded so a lesson that stops making progress fails as a test rather than hanging the suite.
    for _ = 1, 60 do
        if t.index >= stopAt then break end
        local current = Combat.startTurn(combat)
        if not current then break end
        Tutorial.reconcile(t, isAlive)
        if Tutorial.done(t) then break end
        order[#order + 1] = current.scriptKey
        if os.getenv("TRACE") then
            local at = {}
            for _, u in ipairs(combat.units) do
                if u.alive then
                    at[#at + 1] = string.format("%s=%s", u.char.id:gsub("character_", ""),
                        tostring(u.initiative))
                end
            end
            print(string.format("  %-16s step=%d | %s", tostring(current.scriptKey), t.index,
                table.concat(at, " ")))
        end

        if current.control == "player" then
            runPlayer(combat, t, current, stopAt, refusals)
        else
            runScripted(combat, t, current)
        end
        -- The lesson's own reinforcements, claimed where resolveAdvance claims them: after the
        -- action, ahead of the objective check, so the fight is not won before the grunt lands.
        for _, s in ipairs(Tutorial.claimSpawn(t) or {}) do
            local spawned = Combat.addUnit(combat, Character.instantiate(s.char), "enemy", s.x, s.y)
            spawned.scriptKey = s.x .. "," .. s.y
            if s.initiative then spawned.initiative = s.initiative end
        end
        -- states/battle.lua's pacedTurn, run at the same moment: once the turn has ended.
        local cost = Tutorial.paceTurn(t, current.scriptKey)
        if cost then
            current.initiative = cost
            Combat.rebase(combat)
        end
    end
    return t, combat, order, refusals
end

return {
    {
        name = "every step resolves both a narrative line and a coaching line",
        fn = function()
            -- The steps and their words live in different files (rules in data/tutorials, text in
            -- data/conversations so the extraction tool localizes it). This is what closes that gap:
            -- a renamed or typo'd line id fails here rather than showing an empty panel in-game.
            local def = Tutorial.defs[TUTORIAL]
            assert(def, "the village tutorial is defined")
            local conv = Conversation.defs[def.lines]
            assert(conv, "its conversation exists: " .. tostring(def.lines))
            for i = 1, #def.steps do
                local t = atStep(i)
                local said = Tutorial.narration(t)
                assert(said and said.text ~= "", "step " .. i .. " has no narration")
                assert(said.speaker == def.speaker, "step " .. i .. " speaks as the wrong character")
                local coach = Tutorial.coach(t)
                assert(coach and coach.text ~= "", "step " .. i .. " has no coaching line")
                assert(coach.anchor, "step " .. i .. "'s coaching points at nothing")
                assert(Tutorial.nudge(t) ~= nil, "step " .. i .. " has no refusal line")
            end
            -- Localization only reaches a line the extraction tool stamped.
            for _, node in ipairs(conv.script) do
                assert(node.tag ~= nil, "unstamped line: " .. tostring(node.id))
            end
        end,
    },
    {
        name = "the mentor never speaks interface language, and the coaching always does",
        fn = function()
            -- The whole point of the split (data/tutorials/village.lua): Rowan is a knight in a
            -- burning village, and the moment she says "click the purple tile" she stops being a
            -- character. The interface words are allowed to live in the coaching bubble only.
            local UI_WORDS = { "click", "button", "tile", "cursor", "panel", "slot", "press", "icon" }
            local def = Tutorial.defs[TUTORIAL]
            for i = 1, #def.steps do
                local t = atStep(i)
                local said = Tutorial.narration(t).text:lower()
                for _, word in ipairs(UI_WORDS) do
                    assert(not said:find(word, 1, true),
                        "step " .. i .. "'s narration says '" .. word .. "': " .. said)
                end
                -- And the coaching earns its keep by naming an actual action -- but NEVER by naming
                -- one device's. "Click" is a lie on two of the three inputs this project supports,
                -- so the authored line carries the {select} token and Locale.substitute resolves it
                -- against whatever is in the player's hands (see docs/localization.md).
                local step = Tutorial.defs[TUTORIAL].steps[i]
                local authored
                for _, node in ipairs(Conversation.defs[def.lines].script) do
                    if node.id == step.coach then authored = node.text or node[2] end
                end
                assert(authored, "step " .. i .. "'s coaching line is missing")
                assert(authored:find("{select}", 1, true),
                    "step " .. i .. "'s coaching names no action: " .. authored)
                assert(not authored:lower():find("click", 1, true),
                    "step " .. i .. "'s coaching hard-codes the mouse: " .. authored)
            end
        end,
    },
    {
        name = "the coaching names its button as a key cap, matching the device in the player's hands",
        fn = function()
            -- The three-input rule reaching the screen. The words stay identical across devices --
            -- that is the point of drawing the button instead of writing a verb for it -- and only
            -- the cap changes. It re-resolves per draw, so picking up a pad mid-lesson swaps the key
            -- under the player.
            local InputMode = require("input_mode")
            local was = InputMode.current
            local out = {}
            for _, mode in ipairs({ "mouse", "keyboard", "gamepad" }) do
                InputMode.set(mode)
                local coach = Tutorial.coach(Tutorial.new(TUTORIAL))
                assert(not coach.text:find("{select}", 1, true), mode .. " left the token in the words")
                assert(coach.text ~= "", mode .. " resolved the coaching to nothing")
                out[mode] = coach
            end
            InputMode.set(was)

            -- The two devices with a real labelled button draw it, and share one sentence -- which is
            -- the whole point of drawing rather than writing: no grammar to get right per device.
            assert(out.keyboard.key == "Enter", "the keyboard cap is " .. tostring(out.keyboard.key))
            assert(out.gamepad.key == "A", "the pad cap is " .. tostring(out.gamepad.key))
            assert(out.keyboard.text == out.gamepad.text,
                "the two capped devices disagree on the words, which the cap was meant to prevent")
            for _, word in ipairs({ "click", "enter", "press" }) do
                assert(not out.gamepad.text:lower():find(word, 1, true),
                    "a capped device's sentence hard-codes '" .. word .. "': " .. out.gamepad.text)
            end

            -- The MOUSE is deliberately the odd one out: "Click" is not a key, so drawing it as a cap
            -- would invent a button that does not exist on the device. It gets words and no pill.
            assert(out.mouse.key == nil, "the mouse drew a key cap for a button it does not have")
            assert(out.mouse.text:find("Click", 1, true),
                "the mouse instruction lost its verb: " .. out.mouse.text)
        end,
    },
    {
        name = "a step allows its own action kind and refuses the other four",
        fn = function()
            local t = Tutorial.new(TUTORIAL)
            local step = Tutorial.step(t)
            for _, kind in ipairs(Tutorial.KINDS) do
                local allowed = Tutorial.allows(t, kind)
                if kind == step.gate.kind then
                    assert(allowed, "the step's own kind must be allowed: " .. kind)
                else
                    assert(not allowed, "a step must refuse " .. kind)
                end
            end
        end,
    },
    {
        name = "a finished tutorial unlocks every action",
        fn = function()
            -- The gate must never outlive the lesson, or the fight it opened becomes unplayable.
            local t = atStep(#Tutorial.defs[TUTORIAL].steps + 1)
            assert(Tutorial.done(t), "the lesson is over")
            assert(Tutorial.narration(t) == nil, "a finished tutorial says nothing")
            assert(Tutorial.coach(t) == nil, "a finished tutorial points at nothing")
            for _, kind in ipairs(Tutorial.KINDS) do
                assert(Tutorial.allows(t, kind), "a finished tutorial must allow " .. kind)
            end
        end,
    },
    {
        name = "filterCells opens exactly the band each lesson needs",
        fn = function()
            local input = allCells()

            -- Opening lesson: cross the lane and swing. One legal target cell, and one legal tile to
            -- swing it from -- that approach band is the point. This is the only step reached with a
            -- full move still in hand, so a player who spent it wandering would owe a strike they
            -- could no longer reach with every other action refused (see gate.approach); and every
            -- tile it does offer is one the blow can be thrown from, so the band teaches the walk.
            local t = Tutorial.new(TUTORIAL)
            local step = Tutorial.step(t)
            assert(step.gate.kind == "attack" and step.gate.approach, "step 1 is a walk-and-strike")
            local walk = Tutorial.filterCells(t, "move", input)
            assert(#walk == #step.gate.approach, "the opening walk is the authored approach, got " .. #walk)
            for _, c in ipairs(walk) do
                local ok = false
                for _, a in ipairs(step.gate.approach) do if key(a) == key(c) then ok = true end end
                assert(ok, "an unauthored tile is offered for the approach: " .. key(c))
            end
            local kept = Tutorial.filterCells(t, "attack", input)
            assert(#kept == #step.gate.cells, "the reach is the authored cells, got " .. #kept)
            local want = {}
            for _, c in ipairs(step.gate.cells) do want[key(c)] = true end
            for _, c in ipairs(kept) do assert(want[key(c)], "unauthored cell survived: " .. key(c)) end

            -- Move lesson: one legal tile, and no strike at all -- an imp that closed into reach must
            -- not be swingable at, or the swing spends the turn without satisfying the step.
            local move = atStep(2)
            local moveStep = Tutorial.step(move)
            assert(moveStep.gate.kind == "move" and moveStep.gate.cells, "step 2 pins a move cell")
            assert(#Tutorial.filterCells(move, "move", input) == #moveStep.gate.cells,
                "the move band is the authored cells")
            assert(#Tutorial.filterCells(move, "attack", input) == 0, "the move lesson offers no strike")

            -- Ready-the-ability lesson: still no strike -- the Clear Out has to be taken up first, which
            -- is the entire lesson.
            local arm = atStep(3)
            assert(Tutorial.step(arm).gate.kind == "arm", "step 3 is the arming lesson")
            assert(#Tutorial.filterCells(arm, "attack", input) == 0, "an unarmed unit is offered no strike")

            -- The Clear Out itself: one legal aim cell (the caster's own tile), and the move band left
            -- alone -- the turn's move is already spent on step 2, so there is nothing to pin.
            local clearOut = atStep(4)
            assert(#Tutorial.filterCells(clearOut, "attack", input) == 1, "the Clear Out has one aim point")
            assert(#Tutorial.filterCells(clearOut, "move", input) == #input,
                "a step naming no approach leaves the move band alone")

            -- Every step that opens a FRESH TURN has to pin the feet, or the player can spend the
            -- move walking out of range of the only action the gate still allows -- and then cannot
            -- end the turn either, because wait and forfeit are refused too. A turn opens after any
            -- step that ENDS one (an attack), so those are the steps to check; the arm and cast steps
            -- reached mid-turn are safe on their own, their move already spent.
            local def = Tutorial.defs[TUTORIAL]
            local fresh = true -- step 1 opens the fight
            for i, s in ipairs(def.steps) do
                if fresh then
                    -- Constrained one way or the other: a MOVE step pins the band with its own gate
                    -- cells (that IS the lesson), anything else pins it with `approach`. What must
                    -- never happen is a wide-open band on a turn whose only permitted action has a
                    -- range -- that is the strand.
                    local band = #Tutorial.filterCells(atStep(i), "move", input)
                    assert(band < #input, "step " .. i .. " (" .. s.line .. ") opens a turn with the "
                        .. "whole board walkable and one gated action -- the player can strand "
                        .. "themselves out of its range with no way to end the turn")
                    local pinned = s.gate.approach or (s.gate.kind == "move" and s.gate.cells)
                    assert(band == #pinned, "step " .. i .. "'s move band is not what it declared")
                end
                fresh = s.gate.kind == "attack" -- an attack ends the turn; the next step opens one
            end

            -- The identity case: a finished lesson has no opinion left and must hand back every set
            -- unchanged. Returning {} here would blank the board with nothing to explain it.
            local done = atStep(#Tutorial.defs[TUTORIAL].steps + 1)
            for _, kind in ipairs({ "move", "attack" }) do
                assert(#Tutorial.filterCells(done, kind, input) == #input,
                    "a finished tutorial constrains no " .. kind)
            end
        end,
    },
    {
        name = "the arming lesson admits its own item and no other, and starts it sheathed",
        fn = function()
            local t = atStep(3)
            local step = Tutorial.step(t)
            assert(step.gate.item, "the arming step names the item it wants")
            assert(Tutorial.allowsItem(t, step.gate.item), "the named item may be armed")
            assert(not Tutorial.allowsItem(t, "weapon_iron_sword"),
                "the sword may not stand in for the ability the lesson is about")
            -- The battle arms a unit's default action at the start of every turn. A lesson about
            -- taking up an ability is worthless if the sword is already drawn over it -- worse, the
            -- click it asks for would sheathe whatever the auto-arm drew.
            assert(Tutorial.suppressesAutoArm(t), "the arming lesson holds off the auto-arm")
            for _, i in ipairs({ 1, 2, 4 }) do
                assert(not Tutorial.suppressesAutoArm(atStep(i)),
                    "step " .. i .. " leaves the ordinary auto-arm alone")
            end
            -- Arming the wrong item must not advance the lesson.
            local wrong = atStep(3)
            local ev = satisfyingEvent(Tutorial.step(wrong))
            ev.item = "utility_torch"
            Tutorial.observe(wrong, ev)
            assert(Tutorial.step(wrong).gate.kind == "arm", "the wrong item does not advance")
        end,
    },
    {
        name = "every ability the lesson teaches is one it handed over first",
        fn = function()
            -- An ability lesson is unteachable to someone carrying only a sword, so the lesson gives
            -- the player each ability shortly before asking them to use it. Every gift must be
            -- claimed by a LATER arm step, and every arm step must name an ability the avatar did not
            -- start with -- a step asking the player to ready something they were never given is a
            -- dead end that no amount of clicking gets out of.
            local def = Tutorial.defs[TUTORIAL]
            local starting = {}
            for _, id in ipairs(require("models.registry")
                .load("data/characters", "data.characters")["character_avatar"].startingItems or {}) do
                starting[id] = true
            end

            local granting, seen = {}, {}
            for i, step in ipairs(def.steps) do
                if step.grant then
                    assert(not seen[step.grant], "the lesson gives away " .. step.grant .. " twice")
                    assert(Item.defs[step.grant], "the lesson gives away a nonexistent " .. step.grant)
                    assert(not starting[step.grant],
                        step.grant .. " is already in the avatar's grid -- granting it teaches nothing")
                    seen[step.grant], granting[step.grant] = true, i
                end
            end
            assert(next(granting), "no step hands the player anything")

            for i, step in ipairs(def.steps) do
                if step.gate.kind == "arm" then
                    local at = granting[step.gate.item]
                    assert(at, "step " .. i .. " arms " .. tostring(step.gate.item) ..
                        ", which the lesson never gave the player")
                    -- `<=`, not `<`: a step may hand over the very thing it then asks for. The gift
                    -- is applied from refreshView, which runs before any click of that step can be
                    -- taken, so the item is in the grid by the time the player reaches for it -- and
                    -- "here, take this, now ready it" is a tighter beat than splitting it in two.
                    assert(at <= i, "step " .. i .. " arms " .. step.gate.item .. " before giving it")
                end
            end

            -- Tutorial.grant answers for the CURRENT step only, which is what lets states/battle.lua
            -- apply it every frame without ever duplicating a gift.
            for i = 1, #def.steps do
                assert(Tutorial.grant(atStep(i)) == def.steps[i].grant,
                    "step " .. i .. " grants the wrong thing")
            end
            assert(Tutorial.grant(atStep(#def.steps + 1)) == nil, "a finished lesson gives nothing")
        end,
    },
    {
        name = "the opening step quiets the danger paint, and only the opening step",
        fn = function()
            -- The purple threat wash and the red lines back to whoever throws it are the board's most
            -- useful writing and the worst possible first sentence. The lesson turns them off for the
            -- one step where the player is still learning what a click does, then never again -- a
            -- lesson that kept the board quiet would be teaching them to ignore it.
            local def = Tutorial.defs[TUTORIAL]
            assert(Tutorial.hidesDanger(Tutorial.new(TUTORIAL)),
                "the opening step no longer quiets the danger paint")
            for i = 2, #def.steps do
                assert(not Tutorial.hidesDanger(atStep(i)),
                    "step " .. i .. " is still hiding the danger paint")
            end
            assert(not Tutorial.hidesDanger(atStep(#def.steps + 1)),
                "a finished lesson must hand the board's own overlays back")
            -- Nothing on the far side of a lesson: an ordinary battle passes nil here every frame.
            assert(not Tutorial.hidesDanger(nil), "no tutorial means no opinion about the overlays")
        end,
    },
    {
        name = "the lesson opens with a scene, spoken by the mentor over a board nobody has acted on",
        fn = function()
            local def = Tutorial.defs[TUTORIAL]
            local t = Tutorial.new(TUTORIAL)
            local opening = Tutorial.opening(t)
            assert(opening, "the village lesson opens on a cold board with no scene")
            local conv = Conversation.defs[opening]
            assert(conv, "the opening names no real conversation: " .. tostring(opening))
            assert(#conv.script > 0, "the opening scene is empty")

            -- Spoken by the MENTOR, and by her alone. The opening is the beat that establishes whose
            -- voice is going to be teaching for the next seven steps; handing a line of it to anyone
            -- else costs exactly that.
            for i, node in ipairs(conv.script) do
                assert((node.by or node[1]) == def.speaker,
                    "opening line " .. i .. " is not spoken by the lesson's mentor")
                assert(node.tag ~= nil, "unstamped opening line: " .. i)
            end

            -- ...and it stays in character. Same rule the per-step narration lives under: the scene
            -- plays over the board with the whole interface visible, which is precisely when it would
            -- be most tempting to start naming parts of it.
            local UI_WORDS = { "click", "button", "tile", "cursor", "panel", "slot", "press", "icon" }
            for i, node in ipairs(conv.script) do
                local text = (node.text or node[2]):lower()
                for _, word in ipairs(UI_WORDS) do
                    assert(not text:find(word, 1, true),
                        "opening line " .. i .. " says '" .. word .. "': " .. text)
                end
            end

            -- An abandoned lesson has no opening left to play -- the same rule every other gate obeys.
            local dead = Tutorial.new(TUTORIAL)
            dead.abandoned = true
            assert(Tutorial.opening(dead) == nil, "an abandoned lesson still opens with a scene")
        end,
    },
    {
        name = "reinforcements are claimed once, and land while there is still a fight to join",
        fn = function()
            -- Unlike a grant, a spawn cannot be made idempotent by looking at the board -- the unit
            -- it walks on may already have died. So the lesson remembers, and the memory is what this
            -- checks: a second look at the same step must come back empty, or the grunt is duplicated
            -- every frame the step is current.
            local def = Tutorial.defs[TUTORIAL]
            local spawning
            for i, step in ipairs(def.steps) do
                if step.spawn then
                    assert(not spawning, "more than one step calls for reinforcements")
                    spawning = i
                    for _, s in ipairs(step.spawn) do
                        assert(Character.defs[s.char], "reinforcement names no real character: " .. s.char)
                        assert(s.x and s.y, "reinforcement has nowhere to stand")
                    end
                end
            end
            assert(spawning, "nothing ever reinforces the village fight")

            local t = atStep(spawning)
            local first = Tutorial.claimSpawn(t)
            assert(first and #first > 0, "the step's reinforcements are claimable once")
            assert(Tutorial.claimSpawn(t) == nil, "a claimed spawn must never come back")
            for i = 1, #def.steps do
                if i ~= spawning then
                    assert(Tutorial.claimSpawn(atStep(i)) == nil, "step " .. i .. " spawns nothing")
                end
            end

            -- The timing, and the engine rule underneath it. The grunt arrives AFTER the Clear Out, so
            -- the player watches the imps fall and then the answer walk on -- but the Clear Out clears
            -- the enemy side, and an empty enemy side is a victory (Combat.evaluate). So the lesson
            -- has to be able to say "not yet": Tutorial.awaitsSpawn, which states/battle.lua reads to
            -- hold the win open for exactly the one beat it takes to field the body.
            local lastKill
            for i, step in ipairs(def.steps) do
                if step.gate.kind == "attack" and step.gate.target == "character_demon_imp" then
                    lastKill = i
                end
                -- The Clear Out clears the pair; it names no victim, so find it by the ability instead.
                if step.gate.item == "ability_clear_out" and step.gate.kind == "attack" then lastKill = i end
            end
            assert(lastKill, "no step kills the last imp")
            assert(spawning == lastKill + 1, "the reinforcement must arrive on the step immediately "
                .. "after the last imp dies -- earlier and it looms over an unfinished fight, later "
                .. "and there is no fight left to join")

            local afterKill = atStep(lastKill + 1)
            assert(Tutorial.awaitsSpawn(afterKill),
                "the lesson does not know it still owes the fight a body, so the Clear Out wins the battle")
            Tutorial.claimSpawn(afterKill)
            assert(not Tutorial.awaitsSpawn(afterKill),
                "the lesson keeps holding the victory open after its reinforcement has landed")
            -- ...and the steps that follow need that body alive, which is what makes the wait worth it.
            local needsIt = false
            for i = spawning, #def.steps do
                if def.steps[i].gate.target == "character_demon_grunt" then needsIt = true end
            end
            assert(needsIt, "nothing after the reinforcement ever asks the player to fight it")
        end,
    },
    {
        name = "observe advances only on the action the step asked for",
        fn = function()
            local def = Tutorial.defs[TUTORIAL]
            local step = def.steps[1]
            local cell = step.gate.cells[1]
            local good = { kind = step.gate.kind, actor = step.actor, target = step.gate.target,
                           item = step.gate.item, x = cell.x, y = cell.y }

            local function advanced(overrides)
                local event = {}
                for k, v in pairs(good) do event[k] = v end
                for k, v in pairs(overrides) do event[k] = v end
                local t = Tutorial.new(TUTORIAL)
                Tutorial.observe(t, event)
                return t.index == 2
            end

            assert(advanced({}), "the asked-for action advances the lesson")
            assert(not advanced({ kind = "wait" }), "a different action kind does not advance")
            assert(not advanced({ actor = "character_knight" }), "another unit's action does not advance")
            assert(not advanced({ y = good.y + 1 }), "the right action on the wrong cell does not advance")
            assert(not advanced({ target = "character_knight" }), "hitting the wrong body does not advance")
            -- The item clause is what lets the closing step ask for a NAMED ability: a Clear Out is aimed
            -- at the caster's own tile, so there is no victim to pin it by.
            assert(not advanced({ item = "weapon_iron_axe" }),
                "the right blow struck with the wrong thing does not advance")
        end,
    },
    {
        name = "the authored happy path reaches the end of the lesson",
        fn = function()
            -- Proves no step is unreachable and no gate names an id nothing can satisfy.
            local def = Tutorial.defs[TUTORIAL]
            local t = atStep(#def.steps + 1)
            assert(Tutorial.done(t), "walking every step in order finishes the tutorial")
        end,
    },
    {
        name = "only the scripted ally runs a script, and only until its queue is dry",
        fn = function()
            local def = Tutorial.defs[TUTORIAL]
            local t = Tutorial.new(TUTORIAL)
            local queue = def.script["character_knight"]
            assert(queue and #queue > 0, "Rowan has authored turns")
            for i = 1, #queue do
                local entry = queue[i]
                if entry.through then
                    -- A standing order is HELD, not spent: it comes up again on the next turn, and
                    -- only retires once the lesson passes the step it is posted through. Retired by
                    -- hand here so this walk still covers the whole queue in order.
                    assert(Tutorial.scriptFor(t, "character_knight") == entry,
                        "Rowan's post is offered on the turn it comes up")
                    assert(Tutorial.scriptFor(t, "character_knight") == entry,
                        "Rowan's post is still hers next turn -- a post is not spent by standing it")
                    t.index = entry.through + 1
                else
                    assert(Tutorial.scriptFor(t, "character_knight") == entry,
                        "Rowan's turn " .. i .. " is the authored one, in order")
                end
            end
            -- Dry queue -> nil, which is how the battle state hands her back to the ordinary AI.
            assert(Tutorial.scriptFor(t, "character_knight") == nil,
                "a spent queue yields nil, not a repeat of the last turn")
            assert(Tutorial.scriptFor(t, "character_avatar") == nil,
                "the player's own character is never scripted")
        end,
    },
    {
        name = "the tutorial takes control of Rowan and leaves the avatar to the player",
        fn = function()
            local t = Tutorial.new(TUTORIAL)
            assert(Tutorial.controlFor(t, "character_knight") == "ai", "Rowan runs herself")
            assert(Tutorial.controlFor(t, "character_avatar") == nil, "the avatar stays the player's")
        end,
    },
    {
        name = "the lesson seats the whole opening itself, mentor first",
        fn = function()
            -- The opening of the whole game is an ORDER: Rowan crosses the lane and cuts down her
            -- imp, and only THEN is the player asked to do the same. It is authored rather than
            -- rolled, because gear decides it otherwise and gear is tuned for the fiction -- her
            -- mace is slower than his sword, so left alone the student acts first and the beat he is
            -- meant to be copying has not happened yet.
            local t = Tutorial.new(TUTORIAL)
            assert(Tutorial.paces(t), "the village lesson no longer seats its own turn order")

            -- Position in `pace.order` IS the starting tick, so the opening pass reads straight off
            -- the data -- and the mentor is at the front of it.
            local seats = Tutorial.defs[TUTORIAL].pace.order
            assert(seats[1] == "character_knight",
                "the student is seated ahead of the demonstration: " .. tostring(seats[1]))
            local seen = {}
            for i, k in ipairs(seats) do
                if not seen[k] then -- a unit is seated by its FIRST appearance
                    seen[k] = true
                    assert(Tutorial.startInitiative(t, k) == i - 1,
                        k .. " is not seated where the lesson puts it")
                end
            end
            -- Anything the lesson did not seat sits out of the way rather than cutting in. The two
            -- vanguards are the case: they die on the opening pass and never take a turn.
            assert(Tutorial.startInitiative(t, "4,5") == Tutorial.OFF,
                "a vanguard is seated in the opening order it is supposed to die during")

            -- ...and the pacing goes quiet with the lesson, like the scripts and the gates: the
            -- grunt fight at the end has to finish on the ordinary clock.
            assert(Tutorial.paceTurn(t, "character_knight") ~= nil, "the mentor is paced during the lesson")
            t.index = #Tutorial.defs[TUTORIAL].steps + 1
            assert(Tutorial.done(t), "the lesson is over")
            assert(Tutorial.paceTurn(t, "character_knight") == nil,
                "the lesson's timeline outlived the lesson")
        end,
    },
    {
        name = "played through, the mentor's post clears her flank before the grunt lands",
        fn = function()
            -- The lesson played for real, up to the beat the grunt walks on (step 5). By then the
            -- imps must all be gone -- the player's two to the Clear Out, and the third to the mentor's
            -- standing guard, which is the one the board cannot be trusted to deliver on its own.
            --
            -- The regression: that third imp takes the long way round to her flank, and WHICH of her
            -- turns it arrives on falls out of the initiative order. A guard spent by turn count came
            -- up one turn early, found an empty elbow, and was gone -- leaving a live imp beside her
            -- for the rest of the fight and an uncounted body in a finale whose damage column is
            -- spent to the point.
            local t, combat, order = playVillage(5)
            if os.getenv("TRACE") then print("  ORDER: " .. table.concat(order, " -> ")) end

            assert(t.index == 5, "the lesson stalled before the grunt's beat, at step " .. t.index)
            for _, u in ipairs(combat.units) do
                assert(not (u.alive and u.char.id == "character_demon_imp"),
                    "an imp is still standing when the grunt is due, at ("
                    .. u.x .. "," .. u.y .. ") -- the mentor's flank was never cleared")
            end

            -- She cleared it without leaving her post: every tile she might have advanced to is one
            -- the rest of the choreography needs empty.
            local rowan = livingById(combat, "character_knight")
            assert(rowan, "the mentor did not survive her own demonstration")
            assert(rowan.x == 6 and rowan.y == 6,
                "the mentor wandered off her post to (" .. rowan.x .. "," .. rowan.y .. ")")

            -- ...and the post RETIRES with the phase it belonged to. The imps are done, so her next
            -- authored turn must be the shove at the grunt's cell -- not another turn of standing
            -- guard on an empty board, which is the failure the doubled entry used to cause.
            local nextTurn = Tutorial.scriptFor(t, "character_knight")
            assert(nextTurn and nextTurn.strike and nextTurn.strike.x == 6 and nextTurn.strike.y == 4,
                "the mentor's post outlived the imps instead of retiring into the shove")
        end,
    },
    {
        name = "the whole fight plays in the one order the lesson authored, and the player lands the last blow",
        fn = function()
            -- The lesson end to end, as a sequence of turns. This is the guard the choreography
            -- actually wants: every comment in data/tutorials/village.lua describes an ORDER, the
            -- damage column under `spawn` is counted against it to the point, and until this ran
            -- nothing checked that the fight came out in that order at all -- which is how the
            -- mentor came to lose both of her demonstrations to a tie-break nobody had looked at.
            local def = Tutorial.defs[TUTORIAL]
            local t, combat, order, refusals = playVillage(#def.steps + 1)
            if os.getenv("TRACE") then print("  ORDER: " .. table.concat(order, " -> ")) end

            assert(#refusals == 0, "the board refused a step's own action: "
                .. table.concat(refusals, ", "))
            assert(table.concat(order, " ") == table.concat({
                "character_knight",  -- her demonstration: cross the lane, cut down the vanguard
                "character_avatar",  -- 1. the same, in one click
                "4,2", "6,2",        -- the second wave closes and spits
                "7,3",               -- ...and the third takes the long way to her flank
                "character_knight",  -- her post answers it
                "character_avatar",  -- 2-4. advance, ready, Clear Out -- and the grunt walks on
                "6,1",               -- it charges, and the avatar's sword parries unbidden
                "character_knight",  -- her mace answers, and shoves it two tiles clear
                "character_avatar",  -- 5-6. ready the Jolt and throw it: the stun slides its card
                "character_knight",  -- the turn that stun bought her
                "character_avatar",  -- 7. and the killing blow is the player's
            }, " "), "the fight did not play in the authored order:\n  got:  "
                .. table.concat(order, " -> "))
            assert(Tutorial.done(t), "the lesson did not reach its last step, stopping at " .. t.index)

            -- The stun has to have MOVED something for step 6 to have taught anything: the grunt is
            -- shoved below both of them, and the two turns that buys are the two that kill it.
            -- Pinned as a consequence of the order above -- two party turns between its turn and its
            -- death -- because that is the thing the player actually sees.
            local grunt = livingById(combat, "character_demon_grunt")
            assert(not grunt, "the grunt outlived the lesson")
            for _, u in ipairs(combat.units) do
                assert(u.alive or u.side == "enemy", "the lesson cost the player a unit: " .. u.char.id)
            end
        end,
    },
    {
        name = "the avatar dying abandons the lesson instead of soft-locking the fight",
        fn = function()
            -- Combat.evaluate only calls a loss when EVERY party unit is down, so the avatar can die
            -- while Rowan fights on. With nobody left to teach, the gate must let go of the board.
            local t = Tutorial.new(TUTORIAL)
            Tutorial.reconcile(t, function(id) return id ~= "character_avatar" end)
            assert(t.abandoned, "losing the gated actor abandons the lesson")
            assert(Tutorial.narration(t) == nil, "an abandoned lesson says nothing")
            assert(Tutorial.coach(t) == nil, "an abandoned lesson points at nothing")
            for _, kind in ipairs(Tutorial.KINDS) do
                assert(Tutorial.allows(t, kind), "an abandoned lesson must allow " .. kind)
            end
            assert(Tutorial.scriptFor(t, "character_knight") == nil,
                "an abandoned lesson stops driving its scripted units")
        end,
    },
    {
        name = "a step whose target is already dead is skipped, not left hanging",
        fn = function()
            -- Rowan's own strike, a trap or an overwatch shot can kill the imp the opening step
            -- points at before the player ever swings.
            local t = Tutorial.new(TUTORIAL)
            local step = Tutorial.step(t)
            assert(step and step.gate.target == "character_demon_imp", "step 1 names a target")
            Tutorial.reconcile(t, function(id) return id ~= "character_demon_imp" end)
            assert(t.index == 2 and not t.abandoned,
                "with its target gone the strike step is skipped, not left hanging")
        end,
    },
    {
        name = "the tutorial board is named outright and never rolled at random",
        fn = function()
            -- The regression guard that matters most: tutorial_village lives in data/arenas/ beside
            -- the ordinary forest maps, and without `fixed` it would join their random pool and turn
            -- up in real fights carrying spawn points authored for a scripted lesson.
            for seed = 1, 25 do
                local layout = Arena.pickLayout({ biome = "forest", layout = ARENA, seed = seed }, 2, 3)
                assert(layout.partySpawns[1].x == 4 and layout.partySpawns[1].y == 8,
                    "naming the layout returns it, seed " .. seed)
            end
            local def = Arena.defs[ARENA]
            assert(def and def.fixed, "the tutorial board is marked fixed")
            for seed = 1, 200 do
                local layout = Arena.pickLayout({ biome = "forest", seed = seed }, 4, 4)
                assert(layout.tiles ~= def.tiles,
                    "an ordinary forest fight rolled the tutorial board, seed " .. seed)
            end
        end,
    },
    {
        name = "every cell the lesson names is somewhere a unit can actually stand",
        fn = function()
            -- The payoff of a fixed board: an authored coordinate can be checked instead of trusted.
            local def = Tutorial.defs[TUTORIAL]
            local layout = Arena.defs[def.arena]
            assert(layout, "the tutorial names a real arena: " .. tostring(def.arena))

            local function walkable(c, what)
                assert(c.x >= 1 and c.x <= 8 and c.y >= 1 and c.y <= 8,
                    what .. " is off the board: " .. key(c))
                local tile = layout.tiles[c.y][c.x]
                assert(Arena.TILE_PROPS[tile].walkable, what .. " is unwalkable " .. tile .. ": " .. key(c))
            end

            local moveCells = {}
            for i, step in ipairs(def.steps) do
                for _, c in ipairs(step.gate.cells or {}) do
                    walkable(c, "step " .. i .. "'s gate cell")
                    if step.gate.kind == "move" then moveCells[key(c)] = true end
                end
                if step.anchor and step.anchor.kind == "cell" then
                    walkable(step.anchor, "step " .. i .. "'s anchor")
                end
            end
            for id, queue in pairs(def.script) do
                for i, turn in ipairs(queue) do
                    if turn.move then walkable(turn.move, id .. " turn " .. i .. "'s move") end
                    if turn.strike then walkable(turn.strike, id .. " turn " .. i .. "'s strike") end
                end
            end

            -- Spawns have to leave every tile the player is SENT TO free, or the lesson opens by
            -- asking them to step onto an occupied one. Cells the lesson aims at rather than walks to
            -- are exempt, and deliberately so -- the opening strike names the vanguard's own square.
            assert(#layout.partySpawns >= 2, "the avatar and Rowan both need a spawn")
            assert(#layout.enemySpawns >= 5, "the village fight fields five imps")
            for _, list in ipairs({ layout.partySpawns, layout.enemySpawns }) do
                for _, sp in ipairs(list) do
                    assert(not moveCells[key(sp)], "a spawn sits on a tile the lesson walks to: " .. key(sp))
                end
            end

            local function manhattan(a, b) return math.abs(a.x - b.x) + math.abs(a.y - b.y) end

            -- Find the steps by what they DO rather than by where they sit in the list, so reordering
            -- the lesson doesn't quietly turn these assertions into checks on the wrong beat.
            local openingStrike, standStep, whirlStep
            for _, step in ipairs(def.steps) do
                if step.gate.kind == "attack" and step.gate.item == "weapon_iron_sword"
                    and step.gate.cells and not openingStrike then openingStrike = step end
                if step.gate.kind == "move" then standStep = step end
                if step.gate.kind == "attack" and step.gate.item == "ability_clear_out" then whirlStep = step end
            end
            assert(openingStrike and standStep and whirlStep, "the lesson lost one of its three beats")

            -- NOBODY OPENS IN REACH OF ANYBODY. The first exchange is a walk and then a blow, on both
            -- sides, and the whole opening depends on that staying true: the avatar's one-click
            -- walk-and-strike is what the step teaches, and Rowan's demonstration is only legible
            -- because it is a whole turn rather than an instant. A vanguard that drifted back to
            -- adjacent would quietly delete both lessons while every other assertion still passed.
            local strikeCell = openingStrike.gate.cells[1]
            local avatarSpawn, rowanSpawn = layout.partySpawns[1], layout.partySpawns[2]
            local reach = Character.instantiate("character_avatar").stats.movement + 1
            local d = manhattan(strikeCell, avatarSpawn)
            assert(d >= 3, "the opening strike is a shuffle, not a crossing: " .. d .. " tiles")
            assert(d <= reach, "the opening strike is beyond one turn's walk-and-swing: " .. d)

            local spawned = false
            for _, sp in ipairs(layout.enemySpawns) do
                if key(sp) == key(strikeCell) then spawned = true end
            end
            assert(spawned, "the opening strike names a cell no imp spawns on: " .. key(strikeCell))

            -- Every tile the approach band offers must actually be one the blow can be thrown from,
            -- and one the avatar can get to. That is the band's whole contract -- it is the anti
            -- soft-lock, so a tile in it that cannot strike would be worse than no band at all.
            for _, a in ipairs(openingStrike.gate.approach) do
                walkable(a, "the opening approach tile")
                assert(manhattan(a, strikeCell) == 1,
                    "approach tile " .. key(a) .. " cannot reach the target it is offered for")
                local walked = manhattan(a, avatarSpawn)
                assert(walked <= Character.instantiate("character_avatar").stats.movement,
                    "approach tile " .. key(a) .. " is further than the avatar can walk")
                -- ...and far enough that walking there is a decision. One tile is a shuffle; the
                -- opening is supposed to read as crossing the lane to something.
                assert(walked >= 2, "the avatar's opening walk is only " .. walked .. " tile")
            end

            -- ...and Rowan opens with a kill of her own, one beat ahead of the player: her first
            -- authored turn walks her up to a DIFFERENT imp and cuts it down. Different, or she
            -- takes the player's.
            local hers = def.script["character_knight"][1]
            assert(hers and hers.move and hers.strike,
                "Rowan's opening turn is no longer a walk-and-strike -- her demonstration is gone")
            local hersWalked = manhattan(hers.move, rowanSpawn)
            assert(hersWalked <= Character.instantiate("character_knight").stats.movement,
                "Rowan cannot reach the tile her demonstration walks to (mind the chainmail)")
            assert(hersWalked >= 2, "Rowan's demonstration is only " .. hersWalked .. " tile of walking")
            assert(manhattan(hers.move, hers.strike) == 1, "Rowan's demonstration swings at thin air")
            assert(key(hers.strike) ~= key(strikeCell), "Rowan and the player open on the same imp")
            local rowansTarget = false
            for _, sp in ipairs(layout.enemySpawns) do
                if key(sp) == key(hers.strike) then rowansTarget = true end
            end
            assert(rowansTarget, "Rowan's demonstration swings at a cell no imp spawns on")

            -- The finale, checked as geometry rather than trusted as coordinates that happen to
            -- agree. The move step sends the avatar to ONE tile; the scripted imps close on their
            -- own; and the whole lesson pays off only if that tile is the one adjacent to both, since
            -- a Clear Out sweeps the ring around the body that throws it.
            local standCell = standStep.gate.cells[1]
            -- Measured from where the OPENING KILL leaves the avatar standing -- its approach tile --
            -- not from its spawn. It walked once already; this is the second walk, and the one the
            -- move lesson is actually asking for.
            local afterOpening = openingStrike.gate.approach[1]
            assert(manhattan(standCell, afterOpening) <= Character.instantiate("character_avatar").stats.movement,
                "the avatar cannot reach the tile the lesson sends it to from where the opening kill "
                .. "left it (" .. key(afterOpening) .. " -> " .. key(standCell) .. ")")
            local aoe = Item.defs[standStep.grant].activeAbility.aoe
            assert(aoe.shape == "diamond", "the granted ability no longer sweeps a ring")
            -- Only the IMP queues -- the ones keyed by a cell an imp actually spawns on. Rowan's is
            -- keyed by character id and the grunt's by the cell the lesson walks it on at, and
            -- neither has anything to do with the ring.
            local caught = 0
            for _, sp in ipairs(layout.enemySpawns) do
                local queue = def.script[key(sp)]
                for _, turn in ipairs(queue or {}) do
                    if turn.strike then -- an imp closing to spit at the party: the Clear Out's business
                        assert(manhattan(turn.move, standCell) <= aoe.radius,
                            key(sp) .. " ends outside the Clear Out thrown from " .. key(standCell))
                        caught = caught + 1
                    elseif turn.move then -- ...and the one that closes on Rowan instead
                        assert(manhattan(turn.move, standCell) > aoe.radius,
                            key(sp) .. " ends inside the Clear Out -- the player steals Rowan's kill")
                        -- Measured against the tile her own opening walk leaves her on, not her
                        -- spawn: she has already crossed to make her demonstration by the time this
                        -- one arrives, and her guard only reaches what comes to where she now is.
                        assert(manhattan(turn.move, hers.move) == 1,
                            key(sp) .. " ends out of Rowan's reach, so her guard never takes it")
                    end
                end
            end
            assert(caught == 2, "the finale needs exactly two imps in the ring, found " .. caught)

            -- ...and the aim cell of that Clear Out is the tile just walked onto: a self-centred ability
            -- has exactly one legal target, and the lesson has to name the same one the board offers.
            assert(key(whirlStep.gate.cells[1]) == key(standCell),
                "the closing cast aims at a tile other than the one it was sent to")
        end,
    },
    {
        name = "the numbers the lesson rests on: one blow fells an imp, and one Clear Out fells two",
        fn = function()
            -- The prologue's whole shape is a tuning: the opening strike must KILL (or the first
            -- thing anyone ever does in this game is chip at something), and the closing Clear Out must
            -- kill both (or the lesson ends with the player standing between two live demons). Those
            -- are three blueprints agreeing across three files, so they are checked rather than
            -- commented -- see data/characters/character_demon_imp.lua.
            local tiles = {}
            for y = 1, 8 do
                tiles[y] = {}
                for x = 1, 8 do
                    tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
                end
            end
            local combat = Combat.new({ cols = 8, rows = 8, tiles = tiles },
                { { char = Character.instantiate("character_avatar"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_demon_imp"), x = 1, y = 2 } })
            local avatar, imp = combat.units[1], combat.units[2]
            local health = imp.char.stats.health.current

            for _, id in ipairs({ "weapon_iron_sword", "ability_clear_out" }) do
                local dealt = Combat.computeDamage(combat, avatar, imp, Item.instantiate(id))
                assert(dealt >= health,
                    id .. " leaves an imp standing: " .. dealt .. " against " .. health .. " health")
            end

            -- And the imp cannot pay for that in kind: its Cinder Spit never strikes from an adjacent
            -- tile, because an iron sword's Parry answers ANY adjacent blow (magical or not -- see
            -- tests/counter_preview_spec.lua) and would kill the imp that threw it. The two back imps
            -- have to survive their own attack to be killed together.
            local spit = Item.defs["weapon_cinder_spit"].activeAbility
            assert((spit.minRange or 0) >= 2, "an imp that closes to melee is an imp the lesson loses")
        end,
    },
    {
        name = "the grunt's health is spent exactly, and the player's own blow is the one that ends it",
        fn = function()
            -- The closing beat of the prologue, checked as a sum. The lesson leaves the grunt alive
            -- for the player to finish, and "finish" only means anything if it is genuinely ONE
            -- stroke away -- a grunt that needed two more would trail off, and one that was already
            -- dead would have been killed by somebody else. Four separate blueprints have to agree
            -- for that to come out right, so the agreement is asserted rather than commented.
            local tiles = {}
            for y = 1, 8 do
                tiles[y] = {}
                for x = 1, 8 do
                    tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
                end
            end
            local combat = Combat.new({ cols = 8, rows = 8, tiles = tiles },
                { { char = Character.instantiate("character_avatar"), x = 5, y = 5 },
                  { char = Character.instantiate("character_knight"), x = 6, y = 4 } },
                { { char = Character.instantiate("character_demon_grunt"), x = 5, y = 4 } })
            local avatar, rowan, grunt = combat.units[1], combat.units[2], combat.units[3]

            local sword = Item.instantiate("weapon_iron_sword")
            local parry = Combat.computeDamage(combat, avatar, grunt, sword)   -- its swing, answered
            local jolt = Combat.computeDamage(combat, avatar, grunt, Item.instantiate("ability_jolt"))
            -- Rowan swings her own weapon, whatever the blueprint says it is -- read off her grid so
            -- this stays a statement about the lesson's arithmetic and not about the mace.
            local hers = Combat.computeDamage(combat, rowan, grunt, Combat.defaultWeapon(rowan.char))
            local mine = parry -- the finishing stroke is the same sword swing the parry throws

            -- The column, in order: it charges and is parried, Rowan's mace answers and shoves it
            -- clear, the Jolt crosses the gap, Rowan follows on the turn the stun bought her, and the
            -- player lands the last stroke.
            -- Her SECOND blow lands harder than her first: the shove that comes with it has nowhere
            -- left to go and drives the grunt into the top edge of the board, and Combat.knockback
            -- bills a collision at the weapon's own power (mitigated like any other hit). Counted
            -- here because the ending is tuned around the real number, not the tooltip's.
            local maceAb = Combat.defaultWeapon(rowan.char).activeAbility
            local impact = Combat.mitigatedDamage(grunt, Combat.abilityMagnitude(maceAb),
                { "physical", "impact" })
            local followUp = hers + impact

            local afterShove = grunt.char.stats.health.current - parry - hers
            local afterJolt = afterShove - jolt
            assert(afterJolt > followUp, "Rowan's second blow would KILL the grunt (" .. afterJolt
                .. " left, she lands " .. followUp .. ") -- the last stroke is the player's, not hers")
            local left = afterJolt - followUp
            assert(left > 0, "the grunt is dead before the player's last blow -- somebody stole the kill: "
                .. left)
            assert(left <= mine, "the grunt survives the player's last blow with " .. (left - mine)
                .. " to spare -- the lesson trails off instead of ending")

            -- ...and the Jolt is affordable, which is the mana lesson: casting spends a resource the
            -- player can watch move. The pool is deliberately NOT pinned to a single cast -- how many
            -- the avatar gets is a balance dial, not a lesson -- so only the two ends are asserted:
            -- one cast must be payable (or the tutorial hands over a spell it cannot use), and mana
            -- must not be so deep it reads as free.
            -- Rowan's weapon has to SHOVE, because the closing two steps are built on the gap it
            -- opens: the grunt charges to arm's length, she drives it back, and only then is there a
            -- range for the Jolt to be thrown across. A weapon swap that dropped the knockback would
            -- leave the Jolt taught point-blank -- still a kill, but teaching nothing about reach.
            local hers = Item.defs[Combat.defaultWeapon(rowan.char).id]
            assert(hers.description:lower():find("back", 1, true),
                "Rowan's weapon no longer drives its target back: " .. hers.name)
            assert(Item.defs["ability_jolt"].activeAbility.range >= 2,
                "Jolt has no reach left to teach")

            local cost = Item.defs["ability_jolt"].activeAbility.cost
            assert(cost.stat == "mana", "the lesson's mana beat no longer costs mana")
            local pool = avatar.char.stats.mana.max
            assert(cost.amount <= pool, "the avatar cannot afford the Jolt the lesson hands them")
            -- A loose sanity floor, not a design target: a pool worth ten-plus casts is a pool the
            -- player never watches. Ordinary tuning has room to move well inside this.
            assert(cost.amount * 10 > pool,
                "mana reads as free in the prologue: " .. math.floor(pool / cost.amount) .. " Jolts a fight")
        end,
    },
}
