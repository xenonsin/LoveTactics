-- The prologue: Act 0, the first-time experience (see docs/story.md, "The three acts"). A linear
-- sequence of beats -- scenes, tutorial battles, an overworld leg, the debut bout -- that ends by
-- opening the hub (Act 1). It builds the party through play: the created avatar starts alone, Rowan
-- (the knight) is sworn in the burning village, and Saber (the gladiator) is bested on the
-- Colosseum's sand and joins. The avatar's body and NAME are both chosen before this state runs
-- (states/character_creation.lua); `begin` reads them off Player.active.
--
-- Structure: `beats` is an ordered list of thunks. `next` runs the next one; each beat eventually
-- calls `next` again (a scene on its onDone, an `action` immediately). The two beats that leave this
-- state -- a battle (states.battle) and the overworld (states.game) -- can't call `next` from here, so
-- on their win they set `pendingAdvance` and switch back; `enter` sees the flag and advances. A loss
-- drops to the menu (the run is lost).
--
-- This state is only ever visible dimmed, behind a conversation overlay; a battle or the overworld
-- take over the screen themselves. So its own draw is a plain backdrop and it takes no input.

local State = require("states")
local Scale = require("scale")
local Player = require("models.player")
local Character = require("models.character")

local prologue = {}

-- ---------------------------------------------------------------------------
-- Beat content
-- ---------------------------------------------------------------------------

-- The village defense: three imps, avatar + Rowan. The first fight anyone sees -- so it is also the
-- one that teaches the game. `tutorial` hands states/battle.lua a lesson to enforce
-- (data/tutorials/village.lua): Rowan speaks over her own head, the board accepts only the action she
-- just asked for, and she and the imps run authored turns rather than the AI's. That lesson names
-- exact tiles, so `layout` pins the board it was authored against instead of rolling one.
--
-- Five imps, and the Demon Grunt the lesson walks on itself partway through (the tutorial's `spawn`,
-- which is why it is absent from this composition). Imps rather than grunts for the teaching because
-- an imp dies to exactly one sword blow and a pair of them to one Clear Out -- see
-- data/characters/character_demon_imp.lua, where those numbers are pinned. The grunt is the step up:
-- it takes several blows, and the lesson deliberately ends with it still standing.
local VILLAGE_MAP = {
    biome = "forest",
    layout = "tutorial_village",
    tutorial = "village",
    objective = {
        name = "Defend the Village",
        composition = function()
            return { "character_demon_imp", "character_demon_imp", "character_demon_imp",
                     "character_demon_imp", "character_demon_imp" }
        end,
        win = { type = "killAll" },
    },
    keyCount = 0,
}

-- Exported so tests/prologue_spec.lua can pin the tutorial wiring rather than trust a pair of ids
-- typed into two different files.
prologue.VILLAGE_MAP = VILLAGE_MAP

-- The flight to the capital: a short, real overworld leg (states.game) in the forest, introducing the
-- map and its encounter kinds, with a bandit ambush as the objective.
local FLIGHT_QUEST = {
    name = "The Road to the Capital",
    -- A scene played over the map the instant it appears (states/game.lua fields it on enter). The
    -- overworld is the one screen the prologue hands over with no explanation at all -- markers, fog,
    -- a road -- so Rowan names the aftermath and the errand while the player is looking straight at
    -- it. See data/conversations/prologue_ruins.lua for why it is here and not a beat earlier.
    opening = "prologue_ruins",
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
        tutorial = map.tutorial, -- nil for every fight but the village one
        -- A scene played over the board when this fight opens (states/battle.lua). Any map may name
        -- one; the village's comes from its lesson instead, which is why this is usually nil.
        opening = map.opening,
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
        -- Bested, then kept. The recruit rides on the quest's own `rewardCharacter` now
        -- (data/quests/arena_debut.lua), granted by Quest.complete like any other reward, so the
        -- blueprint is the single source of truth for who this bout is worth rather than a line of
        -- prologue script that a board-taken version of the quest would never run.
        battle(require("models.quest").defs["arena_debut"].map, completeArenaDebut),
        scene("prologue_victory"),
    }
end

function prologue.next()
    prologue.cursor = prologue.cursor + 1
    local beat = prologue.beats[prologue.cursor]
    if beat then beat() else State.switch(require("states.hub")) end
end

-- First entry of a New Game: build the avatar from the body and name chosen at character creation,
-- reset the roster/party to just the avatar (the party is earned through play), and start the beats.
function prologue.begin()
    local p = Player.active
    local avatar = Character.instantiate("character_avatar")
    local body = (p and p.body == 2) and 2 or 1 -- body 1 is the default if creation was skipped
    avatar.sprite = "assets/chars/avatar_" .. body .. ".png"
    avatar.portrait = "assets/portraits/avatar_" .. body .. ".png"
    -- The name is typed at creation, so the avatar is named before the first line is spoken --
    -- Rowan is sworn to you and has to be able to say it. Falls back to the blueprint's "Stranger".
    if p and p.name then avatar.name = p.name end
    prologue.avatar = avatar
    p.roster = { avatar }
    p.party = { avatar }
    prologue.beats = buildBeats()
    prologue.cursor = 0
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
-- Callbacks
-- ---------------------------------------------------------------------------

-- This state never owns interactive UI of its own: every beat either plays a conversation overlay
-- (which takes input itself) or hands the screen to a battle/the overworld. So all it draws is the
-- backdrop those overlays sit against, and it takes no input.
function prologue.draw()
    love.graphics.setColor(0.06, 0.06, 0.09)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    love.graphics.setColor(1, 1, 1)
end

return prologue
