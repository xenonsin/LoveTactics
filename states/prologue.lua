-- The prologue: Act 0, the first-time experience (see docs/story.md, "The three acts"). A linear
-- sequence of beats -- scenes, tutorial battles, an overworld leg, the name prompt, the debut bout --
-- that ends by opening the hub (Act 1). It builds the party through play: the created avatar starts
-- alone, Rowan (the knight) is sworn in the burning village, and Saber (the gladiator) is bested on
-- the Colosseum's sand and joins.
--
-- Structure: `beats` is an ordered list of thunks. `next` runs the next one; each beat eventually
-- calls `next` again (a scene on its onDone, the name prompt on submit, an `action` immediately). The
-- two beats that leave this state -- a battle (states.battle) and the overworld (states.game) -- can't
-- call `next` from here, so on their win they set `pendingAdvance` and switch back; `enter` sees the
-- flag and advances. A loss drops to the menu (the run is lost).
--
-- This state is only ever the *visible* one during the name prompt (it hosts the widget) and, dimmed,
-- behind a conversation overlay; a battle or the overworld take over the screen themselves. So its own
-- draw is a plain backdrop plus, in name mode, the name-entry widget.

local State = require("states")
local Scale = require("scale")
local Player = require("models.player")
local Character = require("models.character")

local prologue = {}

-- ---------------------------------------------------------------------------
-- Beat content
-- ---------------------------------------------------------------------------

-- The village defense: three weak demons, avatar + Rowan. The first fight anyone sees.
local VILLAGE_MAP = {
    biome = "forest",
    objective = {
        name = "Defend the Village",
        composition = function() return { "character_demon_grunt", "character_demon_grunt", "character_demon_grunt" } end,
        win = { type = "killAll" },
    },
    keyCount = 0,
}

-- The flight to the capital: a short, real overworld leg (states.game) in the forest, introducing the
-- map and its encounter kinds, with a bandit ambush as the objective.
local FLIGHT_QUEST = {
    name = "The Road to the Capital",
    map = {
        biome = "forest",
        encounters = { min = 2, max = 3 },
        objective = {
            name = "Ambush on the Road",
            composition = function() return { "character_bandit", "character_bandit" } end,
            win = { type = "killAll" },
        },
        keyCount = 0,
    },
}

-- ---------------------------------------------------------------------------
-- Beat runners
-- ---------------------------------------------------------------------------

-- Come back to this state after a battle/overworld leg and advance to the next beat.
function prologue.resume()
    prologue.pendingAdvance = true
    State.switch(prologue)
end

-- A total-party wipe (or forfeit) ends the run: back to the menu.
local function onLoss()
    State.switch(require("states.menu"))
end

-- Launch an objective battle with the live party. `onWinExtra` (optional) runs once on victory,
-- before advancing -- how the debut recruits Saber and banks its reward.
function prologue.runBattle(map, onWinExtra)
    local p = Player.active
    Player.restore(p) -- each tutorial fight opens fresh; attrition is not the lesson here
    State.switch(require("states.battle"), {
        encounter = { kind = "objective" },
        biome = map.biome,
        prestige = p.prestige,
        party = p.party,
        stash = p.stash,
        quest = { map = map },
        onWin = function()
            if onWinExtra then onWinExtra() end
            prologue.resume()
        end,
        onLoss = onLoss,
    })
end

-- Launch the overworld flight leg, handing control back here (not to the hub) when its objective clears.
function prologue.runOverworld(quest)
    local p = Player.active
    Player.restore(p)
    State.switch(require("states.game"), quest, p.prestige, p, prologue.resume)
end

-- Mark the debut quest complete (banks its gold/rep/prestige and takes it off the board), using a
-- copy that carries the id Quest.complete needs.
local function completeArenaDebut()
    local Quest = require("models.quest")
    local def = Quest.defs["arena_debut"]
    if not def then return end
    local quest = { id = "arena_debut" }
    for k, v in pairs(def) do if quest[k] == nil then quest[k] = v end end
    Quest.complete(Player.active, quest)
end

-- Open the name-entry widget; on submit, write the typed name onto the avatar instance and advance.
function prologue.startNameEntry()
    prologue.mode = "name"
    prologue.nameWidget = require("ui.name_entry").new({
        prompt = "The crowd waits. What name will they roar?",
        onSubmit = function(name)
            if prologue.avatar then prologue.avatar.name = name end
            prologue.mode = nil
            prologue.nameWidget = nil
            prologue.next()
        end,
    })
end

-- ---------------------------------------------------------------------------
-- Beat thunk builders
-- ---------------------------------------------------------------------------

local function scene(id)
    return function() require("models.conversation").play(id, prologue.next) end
end

local function action(fn)
    return function() fn(); prologue.next() end
end

local function battle(map, onWinExtra)
    return function() prologue.runBattle(map, onWinExtra) end
end

local function overworld(quest)
    return function() prologue.runOverworld(quest) end
end

local function nameEntry()
    return function() prologue.startNameEntry() end
end

-- ---------------------------------------------------------------------------
-- Sequencer
-- ---------------------------------------------------------------------------

-- Build the ordered beat list. Held as a builder so a fresh New Game always starts clean.
local function buildBeats()
    return {
        scene("prologue_intro"),
        action(function() Player.recruit(Player.active, "character_knight") end), -- Rowan joins for the fight
        battle(VILLAGE_MAP),
        scene("prologue_flee"),
        overworld(FLIGHT_QUEST),
        scene("prologue_arrival"),
        scene("prologue_arena"),
        nameEntry(),
        battle(require("models.quest").defs["arena_debut"].map, function()
            completeArenaDebut()
            Player.recruit(Player.active, "character_saber") -- bested, then kept
        end),
        scene("prologue_victory"),
    }
end

function prologue.next()
    prologue.cursor = prologue.cursor + 1
    local beat = prologue.beats[prologue.cursor]
    if beat then beat() else State.switch(require("states.hub")) end
end

-- First entry of a New Game: build the avatar from the chosen gender, reset the roster/party to just
-- the avatar (the party is earned through play), and start the beats.
function prologue.begin()
    local p = Player.active
    local avatar = Character.instantiate("character_avatar")
    local male = p and p.gender == "M"
    avatar.sprite = male and "assets/chars/avatar_m.png" or "assets/chars/avatar_f.png"
    avatar.portrait = male and "assets/portraits/avatar_m.png" or "assets/portraits/avatar_f.png"
    prologue.avatar = avatar
    p.roster = { avatar }
    p.party = { avatar }
    prologue.beats = buildBeats()
    prologue.cursor = 0
    prologue.mode = nil
    prologue.next()
end

-- Reached from character creation (a fresh New Game -> begin) or from resume() after a battle/overworld
-- leg (pendingAdvance -> advance). Those are the only two callers, so a plain flag check suffices.
function prologue.enter()
    if prologue.pendingAdvance then
        prologue.pendingAdvance = false
        prologue.next()
    else
        prologue.begin()
    end
end

-- ---------------------------------------------------------------------------
-- Callbacks (only interactive during the name prompt; a plain backdrop otherwise)
-- ---------------------------------------------------------------------------

function prologue.update(dt)
    if prologue.mode == "name" and prologue.nameWidget then prologue.nameWidget:update(dt) end
end

function prologue.draw()
    -- A plain dark backdrop. During a scene this sits (dimmed) behind the conversation overlay; the
    -- name prompt draws its own full screen on top. Battles and the overworld own the screen themselves.
    love.graphics.setColor(0.06, 0.06, 0.09)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    if prologue.mode == "name" and prologue.nameWidget then
        prologue.nameWidget:draw()
    end
    love.graphics.setColor(1, 1, 1)
end

function prologue.keypressed(key)
    if prologue.mode == "name" and prologue.nameWidget then prologue.nameWidget:keypressed(key) end
end

function prologue.textinput(t)
    if prologue.mode == "name" and prologue.nameWidget then prologue.nameWidget:textinput(t) end
end

function prologue.mousemoved(x, y)
    if prologue.mode == "name" and prologue.nameWidget then prologue.nameWidget:mousemoved(x, y) end
end

function prologue.mousepressed(x, y, button)
    if prologue.mode == "name" and prologue.nameWidget then prologue.nameWidget:mousepressed(x, y, button) end
end

function prologue:cursorKind(x, y)
    if prologue.mode == "name" and prologue.nameWidget then return prologue.nameWidget:cursorKind(x, y) end
    return "arrow"
end

function prologue.gamepadpressed(joystick, button)
    if prologue.mode == "name" and prologue.nameWidget then prologue.nameWidget:gamepadpressed(joystick, button) end
end

return prologue
