-- The prologue: Act 0, the first-time experience (see docs/story.md, "The three acts"). A linear
-- sequence of beats -- scenes, tutorial battles, an overworld leg -- that ends by opening the hub
-- (Act 1) at the capital's gate. It builds the party through play: the created avatar starts alone,
-- and Rowan (the knight) is sworn in the ash of Bellmere -- the avatar's own town, and the family
-- holding that burns with the whole household inside it. The third companion, Saber, is NOT recruited
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
    -- Paved, not wooded: Bellmere is a walled market town and this is one of its lanes. Art only on a
    -- curated board -- see the header of data/arenas/tutorial_village.lua, which carries the same
    -- biome and the reason the authored cells are untouched by it.
    biome = "castle",
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
    opening = "conversation_prologue_ruins",
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
            -- The stops after the first chest also hand over class abilities, so the road finishes
            -- introducing the roster of classes the village opened: it taught fighter (Clear Out) and
            -- mage (Jolt) by play, and stop 1 hands the bow (hunter); stops 2-6 cover the rest, one
            -- ability apiece (the last chest carrying two, a second strike and spell for the fighter
            -- and mage the village opened with), delivered through whatever channel the stop already
            -- owns -- an event's gift, a fight's spoils, a chest. Stop 7 is a plain rest and grants
            -- nothing: it exists so the champion is fought fresh. The class rides on WHICH ability,
            -- never on who may hold it (docs/classes.md): this is a lesson, not an equip gate.
            always = {
                -- Stop 1: the teaching chest -- the bow kit (hunter) and the potions that fill the grid.
                { id = "encounter_treasure", loot = {
                    "weapon_iron_bow",
                    "consumable_mana_potion", "consumable_mana_potion",
                    "consumable_healing_potion", "consumable_healing_potion", "consumable_healing_potion",
                } },
                -- Stop 2: priest (Heal) -- the roadside shrine's healing rite, granted by the scene's choices.
                { id = "encounter_event", conversation = "conversation_flight_event_shrine" },
                -- Stop 3: knight (Shout/Taunt) -- won holding the line for the survivors.
                { id = "encounter_survivors_defend", loot = { "ability_shout" } },
                -- Stop 4: alchemist (Assayer's Eye) -- the apothecary's own lens, pressed on you (scene choices).
                { id = "encounter_event", conversation = "conversation_flight_event_survivor" },
                -- Stop 5: rogue (Drain Mana) -- siphoned off the demons blocking the way out, and the
                -- one gift on this road that has to be checked against what the road actually fields.
                -- It used to be inert for the whole rest of Act 0: every demon carried mana = 0, so the
                -- class introduction the stop exists to make spent 4 stamina and restored nothing. The
                -- demons pay for their hellfire in mana now (data/characters/character_demon_imp.lua
                -- states the contract), so the gift has something to bite on for the rest of the road.
                -- The spoils land after the win, so the body it is actually FOR is the Champion at the
                -- end of the trail, whose Roar and Cleave come out of one 60-mana pool -- and the fight
                -- it is won in is the argument for carrying it, since the grunt on this map spends its
                -- own mana burning the road the driver has to walk down.
                { id = "encounter_survivors_extract", loot = { "ability_drain_mana" } },
                -- Stop 6: mage (Fire Bolt) + fighter (Power Strike) -- the last chest before the gate
                -- rounds out the two classes the village opened with, one spell and one strike.
                { id = "encounter_treasure", loot = { "ability_fire_bolt", "ability_power_strike" } },
                -- Stop 7: a plain rest so the champion is fought fresh -- no loot, just a full refill.
                { id = "encounter_rest" },
            },
        },
        objective = {
            name = "The Demon Champion",
            -- A scene played over the board when the boss fight opens (states/game.lua wires the
            -- objective's `opening` through to states/battle.lua). Rowan and the avatar exchange the
            -- last words before the first foe the game frames as a BOSS, with the champion already
            -- standing on the lane behind the text -- see data/conversations/flight_champion.lua.
            opening = "conversation_flight_champion",
            -- The capstone's own authored board (data/arenas/demon_champion.lua), read by
            -- states/battle.lua's specFor off the objective rather than the overworld map's `layout`.
            -- Its terrain answers the boss's three stages (the neck, the high ground, the treeline).
            layout = "demon_champion",
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
        party = p.roster,
        -- No deployment phase in Act 0. Every prologue fight is placed by hand -- a lesson addresses
        -- units by the cell they spawned on, and the flight's beats are authored against specific
        -- tiles -- so the board's own spawns are the placement, exactly as they always were. See
        -- docs/deployment.md.
        deploy = false,
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
    State.switch(require("states.game"), quest, nil, p, prologue.resume)
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
        scene("conversation_prologue_intro"),
        action(function() Player.recruit(Player.active, "character_rowan") end), -- Rowan joins for the fight
        battle(VILLAGE_MAP),
        -- The oath is sworn once the village is held, and "[Rowan has joined your Party]" lands at the
        -- end of this "Ashes" scene -- folded on by Conversation.drainJoins, because her recruit two
        -- beats up queued it (models/conversation.lua). It survives the battle in between because that
        -- fight's tutorial opening plays with `deferJoins` (states/battle.lua): an over-the-board scene
        -- refuses the banner and holds it for the next full scene, which is this one. Every companion is
        -- announced this way, so the prologue does not special-case its first one.
        scene("conversation_prologue_flee"),
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
-- reset the roster to just the avatar (the company is earned through play), and start the beats.
function prologue.begin()
    local p = Player.active
    local avatar = Character.instantiate("character_avatar")
    -- The name is typed at creation, so the avatar is named before the first line is spoken --
    -- Rowan is sworn to you and has to be able to say it. Falls back to the blueprint's "Stranger".
    if p and p.name then avatar.name = p.name end
    prologue.avatar = avatar
    p.roster = { avatar }
    -- Stamp the chosen body's sprite/portrait onto the avatar (Player.applyAvatarBody, which the load
    -- path also runs). The board draws a unit only when char.sprite is a loaded image, so this is what
    -- keeps the avatar from falling back to the bare letter token; it reads p.body, defaulting to body 1.
    Player.applyAvatarBody(p)
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
    -- The prologue has no bed of its own -- its scenes play over a plain backdrop -- so silence the
    -- track the previous screen left running (the title's `music.menu` on the first entry, a fight's
    -- bed on a resume). Its battles and the overworld leg each set their own music on enter, and the
    -- final beat hands off to the hub, which sets `music.hub`; so nothing here re-starts a bed.
    require("models.sound").stopMusic()
    if prologue.pendingAdvance then
        prologue.pendingAdvance = false
        prologue.next()
    else
        prologue.begin()
    end
end

-- ---------------------------------------------------------------------------
-- Skipping Act 0 (debug)
-- ---------------------------------------------------------------------------

-- WHAT THE PROLOGUE IS WORTH, HANDED OVER WITHOUT PLAYING IT. The debug column's "Skip Prologue"
-- (states/menu.lua) starts a New Game and opens the city directly, which means every beat above still
-- has to pay: the hub is met by a company that has been through Act 0 -- two bodies at level 4 carrying
-- a road's worth of kit -- and a level-1 pair with an empty stash reads as a broken city rather than a
-- skipped prologue.
--
-- DERIVED WHERE IT CAN BE. The two abilities Rowan hands over mid-fight, the chests, the loot the two
-- objective lessons carry and the rescue purse are all read off their own sources -- the village
-- lesson's steps, FLIGHT_QUEST, the encounter blueprints -- so a beat that gives one more thing gives
-- it here without this function being touched. Two things are authored, because the data cannot say
-- them: the gifts the "Choose..." stops hand over (each is a branch), and the experience (a figure
-- models/experience.lua states in prose). tests/prologue_skip_spec.lua pins both against their sources.
--
-- WHAT IT DOES NOT HAND OVER is the rolled half of a fight's spoils -- band loot and salvage. Those are
-- a roll rather than something the player was ever "supposed to receive", and the authored lists are
-- what the road was written to give. The GOLD is paid, through Spoils' own arithmetic: a hub is a row
-- of shops, and arriving at them on the starting purse is the one difference that would make the
-- skipped city play differently from the walked-into one.

-- The two gifts the flight's "Choose..." stops hand over, as { item, from }. Authored rather than read
-- out of the scenes because each of those options is a TRADE -- the shrine's rite against a heal, the
-- survivor's lens against a mark -- so nothing in the data says which branch the stop exists to teach.
-- These are the two the route's own comments name: priest at stop 2, alchemist at stop 4.
prologue.SCENE_GIFTS = {
    { item = "ability_renewal",      from = "conversation_flight_event_shrine" },
    { item = "ability_assayers_eye", from = "conversation_flight_event_survivor" },
}

-- ...and the flags those same choices set. Both of the survivor's branches set this one, so taking it
-- says nothing about which was chosen.
prologue.SCENE_FLAGS = { "met_the_survivor" }

-- What Act 0's four fights pay a body. models/experience.lua states the figure from the other end --
-- "the prologue's four fights pay a two-body company around eighty a head, which is level 4 here" --
-- and this is that sentence as a number, so a skipped company stands at the Gate on the level a played
-- one does rather than three below the danger the first floor fights at.
prologue.SKIP_XP = 80

-- How many ACTIONS a body takes in one of those fights, which is the other figure the data cannot
-- state: technique is banked per action (Class.TECHNIQUE_PER_ACTION), and nothing in Act 0 records how
-- many were spent. Ten is what a short scripted fight of a two-body company gets through -- twenty
-- technique a fight, two thirds of the ceiling a fight can pay (Class.TECHNIQUE_PER_BATTLE), so the
-- estimate never sits against the cap and reads as a clamp rather than a count.
prologue.SKIP_ACTIONS_PER_FIGHT = 10

-- WHAT THE FIGHTING BANKS IN THE HOUSES: the half of Act 0's pay that decides what the city LOOKS like
-- when the skip lands in it. Each of the seven class shelves opens at class level 1 in its own class,
-- held by any body on the roster (`unlockClassLevel` on data/buildings/bastion.lua and its six
-- siblings, read through Class.rosterLevel), and a class level is nothing but cumulative technique
-- (Class.classLevel). Experience alone left every body at nought in every house, so a skipped company
-- reached a houses board with all seven doors shut and no way to open one short of a descent -- the
-- opposite of what the button is for.
--
-- PAID THE WAY A FIGHT PAYS IT (Combat.awardTechnique): every action banks TECHNIQUE_PER_ACTION, split
-- between the house of the thing in the hand and the body's DECLARED house, which takes
-- TECHNIQUE_DECLARED_SHARE of it -- all of it when the two are the same. So the badge rides every
-- action and a body's technique concentrates where it is declared, which is why the company reaches the
-- city holding the Bastion (Rowan, declared knight, and the avatar's starting sword is the Bastion's
-- shelf too) and the Colosseum (the avatar's own badge, fighter by Growth.NEUTRAL_CLASS) and not the
-- other five. The road INTRODUCES all seven classes, one opener apiece -- but introducing is not
-- swinging, and a played Act 0 does not open those doors either.
--
-- WHAT IS APPROXIMATED is the mix, because nothing recorded it: the actions divide evenly across the
-- castable classes on the body's grid -- `activeAbility`, since an item with no cast is never the thing
-- in the hand. Capped per house at what the fights could physically have paid, the same per-fight
-- ceiling a real fight enforces.
local function bankTechnique(player, fights)
    local Class = require("models.class")
    local Growth = require("models.growth")

    local budget = fights * prologue.SKIP_ACTIONS_PER_FIGHT
    local ceiling = fights * Class.TECHNIQUE_PER_BATTLE

    for _, char in ipairs(player.roster) do
        -- The houses this body could have been swinging, in grid order and without repeats.
        local keys = {}
        for _, item in ipairs(Character.eachItem(char)) do
            local key = item.activeAbility and Class.growthClasses(item)[1]
            if key then
                local seen = false
                for _, held in ipairs(keys) do if held == key then seen = true end end
                if not seen then keys[#keys + 1] = key end
            end
        end

        local declared = Growth.classOf(char)
        local banked = {}
        local function bank(key, amount)
            if not key then return end
            amount = math.min(amount, ceiling - (banked[key] or 0))
            if amount <= 0 then return end
            banked[key] = (banked[key] or 0) + amount
            Character.recordTechnique(char, key, amount)
        end

        if #keys == 0 then
            -- A body carrying nothing castable still fought: the whole action goes to the badge, which
            -- is what Combat.awardTechnique pays when the hands vote for nothing.
            bank(declared, budget * Class.TECHNIQUE_PER_ACTION)
        else
            for i, key in ipairs(keys) do
                -- The even split, with the remainder on the first houses rather than lost to floor().
                local actions = math.floor(budget / #keys) + ((i <= budget % #keys) and 1 or 0)
                local share = (declared ~= key) and Class.TECHNIQUE_DECLARED_SHARE or 0
                bank(key, actions * (Class.TECHNIQUE_PER_ACTION - share))
                bank(declared, actions * share)
            end
        end
    end
end

-- Apply everything Act 0 grants to `player`, in the order the beats grant it, and leave the city in
-- free play. Called INSTEAD of prologue.begin -- this state never runs.
function prologue.skip(player)
    local Experience = require("models.experience")
    local Encounter = require("models.encounter")
    local Spoils = require("models.spoils")
    local Conversation = require("models.conversation")
    local Tutorial = require("models.tutorial")
    local Item = require("models.item")

    -- The avatar, built exactly as begin() builds it: the typed name and chosen body when character
    -- creation ran, the blueprint's own "Stranger" and body 1 when it did not -- the skip does not stop
    -- to ask, which is the whole point of it.
    local avatar = Character.instantiate("character_avatar")
    if player.name then avatar.name = player.name end
    prologue.avatar = avatar
    player.roster = { avatar }
    Player.applyAvatarBody(player)

    -- Rowan, sworn in the ash of Bellmere.
    Player.recruit(player, "character_rowan")
    -- ...and her join banner dropped on the floor. Player.recruit queues "[Rowan has joined your Party]"
    -- for the next scene to play (models/conversation.lua), and the scene it belongs to -- "Ashes" -- is
    -- one of the ones being skipped. Left queued it would fold onto whatever the city opens first, which
    -- is a vendor's greeting three buildings later.
    local joins = Conversation.pendingJoins
    for i = #joins, 1, -1 do joins[i] = nil end

    -- WHAT ROWAN HANDS OVER IN THE VILLAGE LANE, which is the one part of Act 0 that does not land in the
    -- stash. The village lesson gives the avatar Clear Out and then Jolt mid-fight (`grant` on a step,
    -- data/tutorials/village.lua), straight into the grid -- "it stays there after the battle, the art
    -- is the avatar's now, not a prop" -- and states/battle.lua puts them there with Character.addItem
    -- rather than Player.grantItem. So they go on the BODY here too: a skip that filed them in the
    -- stash would open the city with an avatar whose grid is the two blueprint items and nothing the
    -- prologue taught.
    --
    -- Read off the lesson itself, step by step, so a lesson that hands over a third thing hands it over
    -- here as well. `actor` names who receives it -- both of the village's are the avatar's, but the
    -- field is what the battle reads and this has no business assuming.
    local lesson = Tutorial.defs[VILLAGE_MAP.tutorial]
    for _, step in ipairs((lesson and lesson.steps) or {}) do
        if step.grant then
            for _, char in ipairs(player.roster) do
                if char.id == step.actor then
                    local held = false
                    for _, item in ipairs(Character.eachItem(char)) do
                        if item.id == step.grant then held = true end
                    end
                    -- A full grid refuses, exactly as the lesson's own grant does; nothing in Act 0
                    -- fills one, so this is a guard rather than a case.
                    if not held then Character.addItem(char, Item.instantiate(step.grant)) end
                end
            end
        end
    end

    -- Every stop's authored loot: the two teaching chests, and the class abilities the two objective
    -- lessons are won with. Read off the route rather than re-listed here.
    local stops = FLIGHT_QUEST.map.encounters.always
    for _, stop in ipairs(stops) do
        for _, id in ipairs(stop.loot or {}) do Player.grantItem(player, id) end
    end

    -- The gifts the two scenes press on you, and the flag they set.
    for _, gift in ipairs(prologue.SCENE_GIFTS) do Player.grantItem(player, gift.item) end
    player.flags = player.flags or {}
    for _, flag in ipairs(prologue.SCENE_FLAGS) do player.flags[flag] = true end

    -- What the road pays for the fighting. Each combat stop rolls its gold through the same arithmetic
    -- the fight would have (Spoils.roll at day 1 -- Act 0 is played before the calendar starts), and a
    -- stop that prices its charges PER HEAD pays for all of them: models/encounter_battle.lua counts the
    -- ones still standing, and a skip hands over the run where everybody walked out.
    local function payFight(count)
        Player.addGold(player, Spoils.roll({ count = count, day = 1 }).gold)
    end
    -- Counted rather than typed, because the technique below is priced per fight: the village lane to
    -- start with, a stop for every route entry that fields a composition, and the champion at the end.
    -- A road that gains or loses a fight moves both payouts without either figure being touched.
    local fights = 1
    for _, stop in ipairs(stops) do
        local def = Encounter.defs[stop.id]
        if def and def.composition then
            fights = fights + 1
            payFight(#def.composition({ day = 1 }))
            local rescue = def.rescue
            if rescue then
                local heads = #(def.allies or {})
                Player.addGold(player, (rescue.gold or 0) * heads)
                for _ = 1, heads do
                    for _, id in ipairs(rescue.loot or {}) do Player.grantItem(player, id) end
                end
            end
        end
    end
    -- ...and the champion at the end of the trail, whose fight is the map's objective rather than a stop.
    fights = fights + 1
    payFight(#FLIGHT_QUEST.map.objective.composition({ day = 1 }))

    -- What those same fights bank in the houses -- see bankTechnique. Banked BEFORE the levels below,
    -- as a fight banks it: Growth.resolve snapshots the ledger when a level lands, and technique added
    -- after the snapshot would read as a level's worth of progress the company has not made since.
    bankTechnique(player, fights)

    -- The experience those fights pay, resolved into levels through Growth exactly as a won fight
    -- resolves it (states/game.lua's post-fight seam). Awarded after the recruit, so Rowan is not handed
    -- the median of a company that has not earned anything yet.
    for _, char in ipairs(player.roster) do
        Experience.award(char, prologue.SKIP_XP)
        Experience.resolve(char)
    end

    -- Stop 7 is a plain rest, so the company reaches the gate whole.
    Player.restore(player)

    -- ...and the city opens in FREE PLAY. begin() sets `hubIntro = "arrival"`, which plays the guard and
    -- the sponsor over the plaza and then shuts every door but the Gate until they have been read
    -- (states/hub.lua). That staging is the tail of the first-time experience this button exists to get
    -- past, so it is not set: the skip lands in the city a played prologue leaves behind.
    player.hubIntro = nil
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
