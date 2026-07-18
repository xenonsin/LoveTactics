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
                -- And the coaching earns its keep by naming the actual verb.
                local coach = Tutorial.coach(t).text:lower()
                assert(coach:find("click", 1, true), "step " .. i .. "'s coaching names no action")
            end
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

            -- Move lesson: one legal tile, and no strike at all -- a demon that wandered into reach
            -- must not be swingable at, or the swing spends the turn without satisfying the step.
            local t = Tutorial.new(TUTORIAL)
            local step = Tutorial.step(t)
            assert(step.gate.kind == "move" and step.gate.cells, "step 1 pins a move cell")
            local kept = Tutorial.filterCells(t, "move", input)
            assert(#kept == #step.gate.cells, "the move band is the authored cells, got " .. #kept)
            local want = {}
            for _, c in ipairs(step.gate.cells) do want[key(c)] = true end
            for _, c in ipairs(kept) do assert(want[key(c)], "unauthored cell survived: " .. key(c)) end
            assert(#Tutorial.filterCells(t, "attack", input) == 0, "the move lesson offers no strike")

            -- Ready-your-weapon lesson: still no strike -- the sword has to be drawn first, which is
            -- the entire lesson.
            local arm = atStep(2)
            assert(Tutorial.step(arm).gate.kind == "arm", "step 2 is the arming lesson")
            assert(#Tutorial.filterCells(arm, "attack", input) == 0, "an unarmed unit is offered no strike")

            -- Strike lesson: the target is pinned by character id, so the approach stays the
            -- player's -- both bands are left wide open.
            local strike = atStep(3)
            assert(Tutorial.step(strike).gate.cells == nil, "the strike step names no cells")
            assert(#Tutorial.filterCells(strike, "move", input) == #input,
                "the strike lesson must leave the approach open")
            assert(#Tutorial.filterCells(strike, "attack", input) == #input,
                "the strike lesson must leave the reach open")

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
        name = "the arming lesson admits its own weapon and no other, and starts it sheathed",
        fn = function()
            local t = atStep(2)
            local step = Tutorial.step(t)
            assert(step.gate.item, "the arming step names the weapon it wants")
            assert(Tutorial.allowsItem(t, step.gate.item), "the named weapon may be armed")
            assert(not Tutorial.allowsItem(t, "utility_torch"), "another item may not stand in for it")
            -- The battle arms a unit's default action at the start of every turn. A lesson about
            -- drawing your sword is worthless if the sword is already drawn -- worse, the click it
            -- asks for would sheathe it again.
            assert(Tutorial.suppressesAutoArm(t), "the arming lesson holds off the auto-arm")
            for _, i in ipairs({ 1, 3 }) do
                assert(not Tutorial.suppressesAutoArm(atStep(i)),
                    "step " .. i .. " leaves the ordinary auto-arm alone")
            end
            -- Arming the wrong item must not advance the lesson.
            local wrong = atStep(2)
            local ev = satisfyingEvent(Tutorial.step(wrong))
            ev.item = "utility_torch"
            Tutorial.observe(wrong, ev)
            assert(Tutorial.step(wrong).gate.kind == "arm", "the wrong weapon does not advance")
        end,
    },
    {
        name = "observe advances only on the action the step asked for",
        fn = function()
            local def = Tutorial.defs[TUTORIAL]
            local step = def.steps[1]
            local cell = step.gate.cells[1]
            local good = { kind = step.gate.kind, actor = step.actor, x = cell.x, y = cell.y }

            local function fresh() return Tutorial.new(TUTORIAL) end
            local function advanced(event)
                local t = fresh()
                Tutorial.observe(t, event)
                return t.index == 2
            end

            assert(advanced(good), "the asked-for action advances the lesson")
            assert(not advanced({ kind = "wait", actor = good.actor, x = good.x, y = good.y }),
                "a different action kind does not advance")
            assert(not advanced({ kind = good.kind, actor = "character_knight", x = good.x, y = good.y }),
                "another unit's action does not advance")
            assert(not advanced({ kind = good.kind, actor = good.actor, x = good.x, y = good.y + 1 }),
                "the right action on the wrong cell does not advance")
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
                assert(Tutorial.scriptFor(t, "character_knight") == queue[i],
                    "Rowan's turn " .. i .. " is the authored one, in order")
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
            -- Rowan's own strike, a trap or an overwatch shot can kill the demon the strike step
            -- points at before the player ever swings.
            local t = atStep(3)
            local step = Tutorial.step(t)
            assert(step and step.gate.target == "character_demon_grunt", "step 3 names a target")
            Tutorial.reconcile(t, function(id) return id ~= "character_demon_grunt" end)
            assert(Tutorial.done(t), "with its target gone the strike step is skipped")
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
                assert(layout.partySpawns[1].x == 4 and layout.partySpawns[1].y == 7,
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

            local named = {}
            for i, step in ipairs(def.steps) do
                for _, c in ipairs(step.gate.cells or {}) do
                    walkable(c, "step " .. i .. "'s gate cell")
                    named[key(c)] = true
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

            -- Spawns have to leave the authored cells free, or the lesson opens by asking the player
            -- to step onto an occupied tile.
            assert(#layout.partySpawns >= 2, "the avatar and Rowan both need a spawn")
            assert(#layout.enemySpawns >= 3, "the village fight fields three demons")
            for _, list in ipairs({ layout.partySpawns, layout.enemySpawns }) do
                for _, sp in ipairs(list) do
                    assert(not named[key(sp)], "a spawn sits on an authored cell: " .. key(sp))
                end
            end

            -- The move step lands the avatar next to a demon that is STILL STANDING THERE -- the
            -- party outruns every grunt on initiative, so the vanguard has not had a turn yet. This
            -- is what lets move, ready and strike be one continuous lesson on the opening turn
            -- instead of three turns with a wait in the middle. Break it and step 3 has no target.
            local moveCell = def.steps[1].gate.cells[1]
            local adjacent = false
            for _, sp in ipairs(layout.enemySpawns) do
                if math.abs(sp.x - moveCell.x) + math.abs(sp.y - moveCell.y) == 1 then adjacent = true end
            end
            assert(adjacent, "the move step must end next to a demon spawn, got " .. key(moveCell))
        end,
    },
}
