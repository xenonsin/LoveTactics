-- The prologue: Act 0, the first-time experience (see docs/story.md, "The three acts"). A linear
-- sequence of beats -- scenes, tutorial battles, an overworld leg -- that ends by opening the hub
-- (Act 1) at the capital's gate. It builds the party through play: the created avatar starts alone,
-- and Rowan (the knight) is sworn in the burning village. The third companion, Saber, is NOT recruited
-- here: the Colosseum debut that bests her is now the hub's own first-visit beat, taken from the Quest
-- Board like any other quest (data/quests/arena_debut.lua carries the recruit and the victory scene as
-- its reward and `outro`). See states/hub.lua, which owns the arrival. The avatar's body and NAME are
-- both chosen before this state runs (states/character_creation.lua); `begin` reads them off
-- Player.active, and sets the flag the hub reads to know this is the first time through its gate.
--
-- Structure: `beats` is an ordered list of thunks. `next` runs the next one; each beat eventually
-- calls `next` again (a scene on its onDone, an `action` immediately). The two beats that leave this
-- state -- a battle (states.battle) and the overworld (states.game) -- can't call `next` from here, so
-- on their win they set `pendingAdvance` and switch back; `enter` sees the flag and advances. A loss
-- does NOT end the run (Act 0 is played before the hub): it restarts the fight it lost from a pre-fight
-- snapshot (see prologue.runBattle / states.game's tutorial retry).
--
-- This state is only ever visible dimmed, behind a conversation overlay; a battle or the overworld
-- take over the screen themselves. So its own draw is a plain backdrop and it takes no input.

local State = require("states")
local Scale = require("scale")
local Player = require("models.player")
local Save = require("models.save")
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
-- The flight is where the overworld teaches itself. `tutorial = "flight"` turns states/game.lua's
-- coach flow on (the move/loadout/equip bubbles and the Loadout button that stays hidden until the
-- first chest is opened); `layout = "tutorial_flight"` pins a HAND-AUTHORED map
-- (data/overworld/tutorial_flight.lua) rather than rolling one, so the chest is always the first thing
-- ahead and the sequence below is walked in exactly this order -- lessons and fights interleaved, the
-- rest on the doorstep of the mini-boss, and the boss itself at the end of the trail. The `always` list
-- is still the single source of each stop's content; the layout only fixes where each one sits.
local FLIGHT_QUEST = {
    name = "The Road to the Capital",
    -- A scene played over the map the instant it appears (states/game.lua fields it on enter). The
    -- overworld is the one screen the prologue hands over with no explanation at all -- markers, fog,
    -- a road -- so Rowan names the aftermath and the errand while the player is looking straight at
    -- it. See data/conversations/prologue_ruins.lua for why it is here and not a beat earlier.
    opening = "prologue_ruins",
    map = {
        biome = "forest",
        tutorial = "flight",
        layout = "tutorial_flight", -- authored, not generated (see data/overworld/tutorial_flight.lua)
        encounters = {
            -- The route stops, in walking order -- the layout's numbered cells (1..7) host these by
            -- index. A treasure to teach loot + the loadout panel, story events between the fights, the
            -- two combat-objective lessons (defend, then extract), a last chest, and a rest so the
            -- champion is fought fresh. Each entry may carry a payload (a treasure's exact `loot`, an
            -- event's `conversation`); see states/game.lua.
            --
            -- Every stop AFTER the first chest also hands over ONE class ability, so the road finishes
            -- introducing the roster of classes the village opened: it taught fighter (Clear Out) and
            -- mage (Jolt) by play, and stop 1 hands the bow (hunter); stops 2-7 cover the rest, one
            -- basic mechanic apiece, delivered through whatever channel the stop already owns -- an
            -- event's gift, a fight's spoils, a chest, the last rest. The class rides on WHICH ability,
            -- never on who may hold it (docs/classes.md): this is a lesson, not an equip gate.
            always = {
                -- Stop 1: the teaching chest -- the bow kit (hunter) and the potions that fill the grid.
                { id = "encounter_treasure", loot = {
                    "weapon_iron_bow",
                    "consumable_mana_potion", "consumable_mana_potion",
                    "consumable_healing_potion", "consumable_healing_potion", "consumable_healing_potion",
                } },
                -- Stop 2: priest (Heal) -- the roadside shrine's mending rite, granted by the scene's choices.
                { id = "encounter_event", conversation = "flight_event_shrine" },
                -- Stop 3: knight (Shout/Taunt) -- won holding the line for the survivors.
                { id = "encounter_survivors_defend", loot = { "ability_shout" } },
                -- Stop 4: alchemist (Disarm) -- a vial of solvent the survivor presses on you (scene choices).
                { id = "encounter_event", conversation = "flight_event_survivor" },
                -- Stop 5: rogue (Pickpocket) -- lifted on the way out of the extraction.
                { id = "encounter_survivors_extract", loot = { "ability_pickpocket" } },
                -- Stop 6: mage (Fire Bolt) -- a spell tucked into a later chest.
                { id = "encounter_treasure", loot = { "ability_fire_bolt" } },
                -- Stop 7: fighter (Power Strike) -- the party sharpens for the gate on the last rest.
                { id = "encounter_rest", loot = { "ability_power_strike" } },
            },
        },
        objective = {
            name = "The Demon Champion",
            -- A scene played over the board when the boss fight opens (states/game.lua wires the
            -- objective's `opening` through to states/battle.lua). Rowan and the avatar exchange the
            -- last words before the first foe the game frames as a BOSS, with the champion already
            -- standing on the lane behind the text -- see data/conversations/flight_champion.lua.
            opening = "flight_champion",
            composition = function()
                return { "character_demon_champion", "character_demon_imp", "character_demon_imp" }
            end,
            win = { type = "assassinate", target = "character_demon_champion" },
        },
        keyCount = 0,
    },
}

-- Exported so tests/flight_leg_spec.lua can pin the tutorial route rather than trust ids typed across
-- several files (the same reason VILLAGE_MAP is exported above).
prologue.FLIGHT_QUEST = FLIGHT_QUEST

-- ---------------------------------------------------------------------------
-- Beat runners
-- ---------------------------------------------------------------------------

-- Come back to this state after a battle/overworld leg and advance to the next beat.
function prologue.resume()
    prologue.pendingAdvance = true
    State.switch(prologue)
end

-- Launch an objective battle with the live party. `onWinExtra` (optional) runs once on victory,
-- before advancing -- how the debut recruits Saber and banks its reward.
--
-- A wipe (or forfeit) no longer ends the run: Act 0 is played before the player ever reaches the hub,
-- so a loss restarts THIS same fight from a snapshot taken just before it, with a whole party. The
-- snapshot is in-memory only (no disk save); resources are refilled again on the retry.
function prologue.runBattle(map, onWinExtra)
    local p = Player.active
    Player.restore(p) -- each tutorial fight opens fresh; attrition is not the lesson here
    local retrySnapshot = Save.snapshot(p)
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
        -- The defeat panel's "Try Again": restart this same fight from the pre-fight snapshot. There is
        -- no "Return to Hub" here (no onLoss) -- Act 0 runs before the hub exists, so retrying is the
        -- only way out and a tutorial loss never ends the run.
        onRetry = function()
            local fresh = Save.restore(retrySnapshot)
            if fresh then
                -- Copy the restored fields onto Player.active in place, so every reference to the live
                -- player (this state's `p`, and states/game.lua's) carries the fresh roster/party.
                for k, v in pairs(fresh) do Player.active[k] = v end
            end
            prologue.runBattle(map, onWinExtra) -- retry the same fight (re-restores resources)
        end,
    })
end

-- Launch the overworld flight leg, handing control back here (not to the hub) when its objective clears.
function prologue.runOverworld(quest)
    local p = Player.active
    Player.restore(p)
    State.switch(require("states.game"), quest, p.prestige, p, prologue.resume)
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
        -- The oath is sworn once the village is held, and "[Rowan has joined your Party]" lands at the
        -- end of this "Ashes" scene -- folded on by Conversation.drainJoins, because her recruit two
        -- beats up queued it (models/conversation.lua). It survives the battle in between because that
        -- fight's tutorial opening plays with `deferJoins` (states/battle.lua): an over-the-board scene
        -- refuses the banner and holds it for the next full scene, which is this one. Every companion is
        -- announced this way, so the prologue does not special-case its first one.
        scene("prologue_flee"),
        overworld(FLIGHT_QUEST),
        -- The flight ends at the capital's gate, and the prologue with it: prologue.next past the last
        -- beat opens the hub. The arrival is the hub's to stage now (states/hub.lua reads the hubIntro
        -- flag begin() set): the guard scene plays over the city, the Quest Board is coached, and the
        -- Colosseum debut is taken from the board -- arena_debut carries the Saber recruit
        -- (`rewardCharacter`) and the victory scene (`outro = prologue_victory`), so the climax and the
        -- companion are the quest's own reward rather than a line of script a board-taken run would skip.
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
    -- The hub reads this on the first visit to stage the arrival (the guard scene over the city) and
    -- coach the Quest Board (states/hub.lua). Set only for a New Game -- a loaded save never runs this
    -- state, so its hub opens straight to free play with no flag to see.
    p.hubIntro = "arrival"
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
