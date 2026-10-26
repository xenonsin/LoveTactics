-- The prologue: Act 0, the first-time experience (see docs/story.md, "The three acts"). A linear
-- sequence of beats -- scenes, tutorial battles, an overworld leg -- that ends by opening the hub
-- (Act 1). It builds the party through play: the created avatar starts alone, and Rowan (the knight)
-- fights beside them from the first fight.
--
-- IT IS THE COMPANY'S FIRST TRIP DOWN (2026-10-16). The city is built around the rift and lives on what
-- adventurers carry up; the avatar means to make a name, and goes down with Rowan to meet a class's
-- requirements. Opening narration, then the name, then the first fight ON FLOOR ONE (Gluttony's wood),
-- then a hand-built floor one modelled like a real one, the Demon Champion on its stair -- a demon where
-- none belongs -- and the walk back out. Xin, who could not come, is met at the Ward the first morning
-- home. (It used to be a breach inside the city walls, fought street by street; ids kept the old words --
-- `tutorial_village`, `tutorial_flight`, FLIGHT_QUEST -- because renaming them is a sweep across the specs
-- and the lang file, not a story change.)
--
-- Nothing is sworn to anybody in Act 0. The third companion, Saber, is NOT recruited
-- here: the Colosseum debut that bests her is now the hub's own first-visit beat, taken from the Quest
-- Board like any other quest (data/quests/arena_debut.lua carries the recruit and the victory scene as
-- its reward and `outro`). See states/hub.lua, which owns the arrival. The avatar's name is chosen at
-- character creation (and nothing else -- it stays the blueprint's human), the beat after the opening narration (states/character_creation.lua);
-- `begin` builds a nameless human "Stranger" for it to name and sets the flag the hub reads to know this
-- is the first time through its gate.
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
local Descent = require("models.descent")

local prologue = {}

-- ---------------------------------------------------------------------------
-- Beat content
-- ---------------------------------------------------------------------------

-- The street defense: three imps, avatar + Rowan. The first fight anyone sees -- so it is also the
-- one that teaches the game. `tutorial` hands states/battle.lua a lesson to enforce
-- (data/tutorials/village.lua): Rowan talks it through from the gutter under the board, the board
-- accepts only the action she just asked for, and she and the imps run authored turns rather than the
-- AI's. (On a handheld there is no gutter and she goes quiet for the fight -- the coach bubble, the
-- half that names the control, carries the lesson alone; see states/battle.lua's draw.) That lesson
-- names exact tiles, so `layout` pins the board it was authored against instead of rolling one.
--
-- Five imps, and the Demon Grunt the lesson walks on itself partway through (the tutorial's `spawn`,
-- which is why it is absent from this composition). Imps rather than grunts for the teaching because
-- an imp dies to exactly one sword blow and a pair of them to one Clear Out -- see
-- data/characters/character_demon_imp_tutorial.lua, where those numbers are pinned. The grunt is the step up:
-- it takes several blows, and the lesson deliberately ends with it still standing.
local VILLAGE_MAP = {
    -- Paved, not wooded: this is one of the capital's own lanes, a street away from the breach. Art only on a
    -- curated board -- see the header of data/arenas/tutorial_village.lua, which carries the same
    -- biome and the reason the authored cells are untouched by it.
    biome = "forest",
    layout = "tutorial_village",
    tutorial = "village",
    objective = {
        name = "The Mouth of the Wood",
        composition = function()
            return { "character_demon_imp_tutorial", "character_demon_imp_tutorial", "character_demon_imp_tutorial",
                     "character_demon_imp_tutorial", "character_demon_imp_tutorial" }
        end,
        win = { type = "killAll" },
    },
    keyCount = 0,
}

-- Exported so tests/prologue_spec.lua can pin the tutorial wiring rather than trust a pair of ids
-- typed into two different files.
prologue.VILLAGE_MAP = VILLAGE_MAP

-- The city sweep: a short, real overworld leg (states.game) through the capital's own streets,
-- introducing the map and its encounter kinds, with the Demon Champion at the end of it.
--
-- IT IS NOT A ROAD ANY MORE. This leg used to be the flight to the capital -- a forest map, a king's
-- road, a destination. The premise moved inside the walls, so the same authored chain of stops is now
-- blocks of a breached city: `biome = "castle"` is what re-skins it (the first street is paved for the
-- same reason), and the layout file's own header carries the rest. Every id below still says "flight".
--
-- The sweep is where the overworld teaches itself. `tutorial = "flight"` turns states/game.lua's
-- coach flow on (the move/loadout/equip bubbles and the Loadout button that stays hidden until the
-- first chest is opened); `layout = "tutorial_flight"` pins a HAND-AUTHORED map
-- (data/overworld/tutorial_flight.lua) rather than rolling one, so the chest is always the first thing
-- ahead and the sequence below is walked in exactly this order -- lessons and fights interleaved, the
-- rest on the doorstep of the mini-boss, and the boss itself at the end of the trail. The `always` list
-- is still the single source of each stop's content; the layout only fixes where each one sits.
local FLIGHT_QUEST = {
    name = "Floor One",
    -- A scene played over the map the instant it appears (states/game.lua fields it on enter). The
    -- overworld is the one screen the prologue hands over with no explanation at all -- markers, fog,
    -- a route -- so Rowan names the aftermath and the errand while the player is looking straight at
    -- it. It also carries the two lines that used to be a scene beat of their own between the fight
    -- and the map, and the join banner with them -- see that file's header.
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
            -- ============================================================================
            -- EVERY GIFT ON THIS ROUTE TEACHES ONE ITEM MECHANIC. That is the whole ladder, and it is
            -- a correction of what this list used to be.
            --
            -- It used to hand over ONE CLASS PER STOP -- priest, knight, alchemist, rogue, mage,
            -- fighter -- so the sweep finished introducing the roster the street fight opened. The
            -- trouble is that a class is not a thing a player can DO anything with on this route.
            -- There is no second body to build, no shelf to shop, no ladder to climb; the city where
            -- a class means something is still two beats away. So six of the seven gifts taught a
            -- NAME, and the two that happened to teach a mechanic (the bow's range band, Mark
            -- Target's grid gate) taught it by accident -- Mark Target on one branch of a coin flip,
            -- and Power Strike's own adjacency requirement never named at all.
            --
            -- What a player CAN use on this route is the thing every one of these gifts actually is:
            -- an item, sitting in a 3x3 grid, with rules about where it sits and what it touches.
            -- So each stop now introduces exactly one of those rules, each leaning on the last:
            --
            --   1  range band              a weapon decides where you may stand
            --   2  adjacency AURA          a charm pays every item it touches        (the grid rewards)
            --   3  forced targeting       an item decides who the enemy swings at
            --   4  adjacency GATE          an item refuses to fire without its neighbour (the grid gates)
            --   5  typed mitigation        a coat answers one KIND of blow and no other
            --   6  a status in your favour   the first one you WANT
            --   7  -                       a plain rest, so the champion is fought fresh
            --
            -- The class an item belongs to is still true of it and is now beside the point (see
            -- docs/classes.md: a class is the vendor shelf that stocks a thing, never an equip gate).
            -- What the stop is FOR is the rule.
            --
            -- FOUR mechanics are deliberately left without a stop, and the last two are a correction
            -- of this ladder rather than an omission from it.
            --
            -- COATINGS -- an aura that is spent as it is used -- want a consumable, and stop 1's
            -- potions are the whole consumable budget of Act 0; they are bought at the Crucible
            -- instead. WIND-UP has no gift because the Champion at the end of the trail IS the
            -- lesson: ability_demon_roar and ability_demon_cleave both channel, armed a turn early
            -- with the telegraph on the board, and meeting the mechanic as a threat you have to move
            -- away from beats meeting it as a button.
            --
            -- THE STANCE SWAP is gone because Rowan already teaches it. Stop 3 used to hand over a
            -- buckler for `waitBehavior`, and its own comment admitted the hole in the argument: the
            -- Sworn Aegis she has carried since the first street (armor_sworn_aegis) swaps Wait into
            -- Defend, so the button on the body the player selects most after their own has read
            -- "Defend" the whole way here. A gift that names a rule the screen has been drawing for
            -- two fights is a caption, not a lesson.
            --
            -- AN ITEM WITH NO BUTTON goes the same way, and it was stop 6's second gift. The avatar
            -- has worn leather and Rowan chainmail since the first fight, neither has ever offered an
            -- action, and no player reaches this chest believing every cell owes them a button. The
            -- item that carried it (utility_second_wind) had a worse problem besides: it is one
            -- refusal to fall, handed over one stop before a script fells Rowan on purpose. The beat
            -- survives it mechanically -- Combat.fell zeroes the body outside the damage pipeline and
            -- never consults Trait.trySurvive -- which only makes the read worse. A player who put
            -- the charm on her watches it stay silent through the exact blow it was sold against.
            -- ============================================================================
            always = {
                -- Stop 1: THE RANGE BAND. The bow reaches 4, needs line of sight, and cannot shoot a
                -- foe standing in your face (minRange 2) -- so the first thing an item ever teaches
                -- is that what you hold decides where you may stand. The potions ride along to teach
                -- the other half of a chest: an item can arrive as a STACK. This is also the stop that
                -- unlocks the Loadout button (states/game.lua's itemsVisible), so the grid lesson has
                -- to start here or it has nowhere to happen.
                { id = "encounter_treasure", loot = {
                    "weapon_iron_bow",
                    "consumable_mana_potion", "consumable_mana_potion",
                    "consumable_healing_potion", "consumable_healing_potion", "consumable_healing_potion",
                } },
                -- Stop 2: THE ADJACENCY AURA -- Wolfsbane Oil, granted by the shrine scene's
                -- choices. The first time the 3x3 is ever anything but storage: put it beside a
                -- weapon and the weapon changes (Combat.auraApplies). It pays out on the very next
                -- block rather than in theory -- adjacent weapons carry the `beastbane` tag
                -- (Combat.BANE), and every body on floor one but the Champion is a beast. The lesson
                -- and its proof are one step apart. It replaced the Dawn Chrism (2026-10-16), whose
                -- holy only paid against demons, once the route moved to floor one and the Champion
                -- became the one demon on it.
                { id = "encounter_event", conversation = "conversation_flight_event_shrine" },
                -- Stop 3: THE ADJACENCY GATE -- Mark Target, off the survivor scene, and it is handed
                -- over on BOTH branches of that choice on purpose. This is the hard half of the grid:
                -- `requiresAdjacent` leaves the item dead unless a ranged weapon touches it, the
                -- combat panel names what is missing in a red broken-link badge, and the loadout
                -- lights the cells that would fix it green (Combat.adjacencyCandidateCells). The bow
                -- from stop 1 is the only answer in the bag, which is why this stop comes after it.
                -- It used to sit on one branch, so half of all players met the rule and half never
                -- did; a lesson decided by a coin flip is not a lesson.
                { id = "encounter_event", conversation = "conversation_flight_event_survivor" },
                -- Stop 4: the last chest before the stair, and ONE lesson -- RENEWAL, a status you
                -- WANT. Everything Act 0 has taught about statuses so far is an injury (Burn, Stun,
                -- Bleed, Mark); this is the first one that helps, it lands on somebody else, and it
                -- keeps working on its own without being cast again. It is also the only healing
                -- ABILITY in Act 0 -- it used to be the shrine's gift, and it moved here when the
                -- shrine took the censer.
                --
                -- It used to be two gifts. The second (utility_second_wind, "an item with no button")
                -- is cut for the two reasons the ladder's header states in full: the worn armor on
                -- both bodies has been teaching that since the first fight, and a charm sold as one
                -- refusal to fall does not belong one stop ahead of a scripted felling it cannot
                -- answer.
                { id = "encounter_treasure", loot = { "ability_renewal" } },
                -- Stop 5: a plain rest so the champion is fought fresh -- no loot, just a full refill.
                { id = "encounter_rest" },
            },
            -- THE TWO RESCUE FIGHTS ARE NOT ON THE MAP (2026-10-16). Floor one fields its ordinary fighting
            -- the way every floor does -- off the walk, a step count at a time (Descent.PROWL_STEPS) -- so
            -- these find the company as it walks rather than standing on a marker it can read and plan
            -- around. In order: `after` is the steps since the last fight that one arrives on, and `by` is
            -- the chokepoint (data/overworld/tutorial_flight.lua's letters) where a fight still owed finds
            -- you if the steps have not, so each gift is in hand before the part of the floor that wants
            -- it. Read by states/game.lua's tutorial prowl. Both fights' own arguments follow.
            --
            -- PLACED BY THE AUTHOR (2026-10-23), on a screenshot of the floor: the first fight around (10,10)
            -- -- the east end of part one's bottom row, 12 steps from the door on the shortest walk -- and
            -- the second around (10,6), just into part two, 8 steps on from there (5 back to the `a`
            -- chokepoint and 3 through it). `after` is those two measurements. It was 6 and 8, then 10 and
            -- 12; both put the first fight too close to the door. And the first is held behind the bow
            -- chest (`waitFor = 1`, the first `always` stop): a company that wanders 12 steps without
            -- opening it does not meet the fight first. The second was then DOUBLED to 16 at the
            -- author's word, which puts it deep in part two rather than just through `a`; the `b`
            -- chokepoint (26 from the door) still owes it if the steps have not.
            --
            -- EACH OPENS ON A SCENE (`opening`, carried onto the cell and handed to the battle -- states/
            -- game.lua), as the village fight and the Champion already do. On the prowl entry rather than
            -- on the encounter blueprint because a blueprint's `opening` would play wherever that
            -- encounter is fielded.
            prowl = {
                -- FIRST: FORCED TARGETING -- the Shout, won on the one stop whose objective is other
                -- people's lives. Every rule the route has taught so far is about what the PLAYER may
                -- do; this is the first item that reaches across the board and decides what the ENEMY
                -- does. Taunt (data/status/status_taunt.lua) makes every foe in the diamond come for
                -- the shouter with their default weapon and nothing else.
                --
                -- The stop is built around it and has been since before the ladder was re-cut: this
                -- fight anchors the survivors AHEAD of the party's line, so the demons walk for them
                -- rather than for you, and the bomblet wave at tick 14 charges them and bursts
                -- (character_demon_bomblet_tutorial). Two bodies cannot physically intercept everything that
                -- fans in from every open side -- the wave's own comment sizes itself against this
                -- gift by name. Pulling the charge onto the wall is the answer, and the proof lands
                -- eight ticks after the item does. Same reason the censer was chosen at stop 2: the
                -- lesson and the thing that pays it off are one step apart.
                --
                -- It also survives the trail. The Champion's Roar and Cleave are lane casts, and a
                -- Shout that drags the bodies beside her out of the lane is the same verb again.
                --
                -- Deeper on the shelf than the rest (bulwark, 660g): a gift waives price, not
                -- standing, and the censer and Mark Target are already crossings the player could not
                -- buy here either.
                { id = "encounter_survivors_defend", loot = { "ability_shout" }, after = 12, by = "a",
                  waitFor = 1, opening = "conversation_flight_defend" },
                -- SECOND: TYPED MITIGATION -- a Salamander Hide off the demons blocking the way out.
                -- The party has worn leather and chainmail since the first fight and nothing has ever
                -- said that a coat answers a KIND of blow; this one is blunt enough to be unmissable
                -- ("Does nothing whatever about anything else") and it is not a guess about what the
                -- route fields. Every imp on it swings weapon_cinder_spit, the grunts throw Brimstone,
                -- the grunt's own claws burn now (weapon_rending_claws.lua) and the Champion is met
                -- with an imp and a grunt beside her. Combat.mitigatedDamage sums the resist of every matching
                -- tag, so the coat blunts all of it. The spoils land after the win, so the body it is
                -- actually FOR is the Champion at the end of the trail.
                { id = "encounter_survivors_extract", loot = { "armor_salamander_hide" }, after = 16, by = "b",
                  opening = "conversation_flight_extract" },
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
            -- ONE IMP AND ONE GRUNT, not two imps. An imp has 14 health for a stated reason -- it dies
            -- to one stroke of the starting sword (character_demon_imp_tutorial.lua argues the number) -- which
            -- makes a pair of them beside the Champion no call on the party's attention at all: two
            -- bodies, two strokes, and both attackers are back on the boss by round two. The grunt is
            -- 80 health and has to be dealt with, so it holds one of the party's two swords away from
            -- the Champion for a turn or two -- which is the same thing as giving the Champion's
            -- wind-ups a window to resolve in. Not a THIRD attacker's worth of incoming damage against
            -- a two-body party; a body that costs turns.
            --
            -- Its claws burn (weapon_rending_claws.lua), so stop 5's Salamander Hide still answers what
            -- walks in here, which is what that gift was placed for.
            composition = function()
                return { "character_demon_champion_tutorial", "character_demon_imp_tutorial", "character_demon_grunt_tutorial" }
            end,
            win = { type = "assassinate", target = "character_demon_champion_tutorial" },
            -- THE CHAMPION STANDS ON THE WAY OUT. Clearing this does not end the leg: the tile it was
            -- holding becomes the road to the city and the company is put back on the map in front of
            -- it, exactly as a circle's guardian opens its stair (models/descent.lua's
            -- Descent.openStair) rather than descending on the killing blow.
            --
            -- WHAT THAT BUYS is the one beat Act 0 had nowhere to put. The kill is where the company
            -- reaches level 2 (prologue.EXIT_LEVEL), and a leg that cut to the city on the same frame
            -- had no moment in which to say so -- the level-up landed in a loading screen. Back on the
            -- map there is a board to stand on and a party strip showing the new level. The road is then the player's own
            -- step, taken when they are finished reading.
            -- THE STAIR OPENS AND THE COMPANY TURNS BACK (2026-10-16). The tile the Champion held becomes
            -- the stair down, which a real floor one's guardian opens -- and nobody takes it: Rowan is down
            -- and nothing like that should be this shallow. The way out is the door the company came in by
            -- (`at = "start"`), so the trip ends the way any trip does, walking back up what it crossed.
            -- Rowan says so the moment the board comes back (`scene`).
            opensExit = { kind = "road", name = "The Way Up", at = "start",
                          stair = "The Stair Down", scene = "conversation_flight_turn_back" },
        },
        keyCount = 0,
    },
}

-- Exported so tests/flight_leg_spec.lua can pin the tutorial route rather than trust ids typed across
-- several files (the same reason VILLAGE_MAP is exported above).
prologue.FLIGHT_QUEST = FLIGHT_QUEST

-- EVERY ITEM ON THIS ROUTE NOW LANDS WITHOUT A BUBBLE. The stops still teach one item mechanic each
-- (see FLIGHT_QUEST's stop-by-stop argument above), but the three that arrived with nobody speaking
-- used to raise a coach bubble over the stash naming the rule -- FLIGHT_LESSONS, keyed on the item id.
-- All three said something the item's own tooltip and the grid already said, over the top of the screen
-- the player had just opened to read them, so the table and the channel that drew it are deleted. What
-- teaches these mechanics is the kit itself and the two conversations that hand a gift over in words
-- (the censer at stop 2, the mark at stop 4).

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
        xpCeiling = prologue.xpCap().ceiling, -- held under the exit level (prologue.xpCap)
        classCredit = false, -- Act 0 teaches no class (Combat.awardTechnique)
        -- A scene played over the board when this fight opens (states/battle.lua). Any map may name
        -- one; the village's comes from its lesson instead, which is why this is usually nil.
        opening = map.opening,
        onWin = function()
            if onWinExtra then onWinExtra() end
            prologue.resume()
        end,
        -- The defeat panel's "Try Again": restart this same fight from the pre-fight snapshot. There is
        -- no "Return to City" here (no onLoss) -- Act 0 runs before the hub exists, so retrying is the
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
-- `resume` (optional) is the saved board from models/save.lua's Save.restoreRun, which puts the company
-- back where it quit with its wounds -- so the refill is skipped for it, as it is for any resumed run.
-- The Champion's horn, the avatar's proof to the guild (data/materials/material_champion_horn.lua).
prologue.HORN_ID = "material_champion_horn"

function prologue.runOverworld(quest, resume)
    local p = Player.active
    if not resume then Player.restore(p) end
    State.switch(require("states.game"), quest, nil, p, prologue.resume, resume)
    -- ...and what Act 0 owes itself the moment the Champion falls, which is BEFORE the leg ends.
    -- The capstone opens the road rather than the city (the objective's `opensExit`), so the company
    -- is put back on the map, and it walks out holding the level the kill pays. Set after the switch
    -- because game.enter clears it.
    local game = require("states.game")
    game.onExitOpened = function()
        prologue.payExit(Player.active)
        -- ...and the PROOF: the Champion's horn, carried home and laid on the guild's counter in the
        -- arrival scene (data/materials/material_champion_horn.lua, states/hub.lua).
        if Player.materialCount(Player.active, prologue.HORN_ID) < 1 then
            Player.addMaterial(Player.active, prologue.HORN_ID, 1)
        end
    end
    -- ...and the hold every fight on the leg banks under, the Champion's paying the exit on its win.
    game.xpCap = prologue.xpCap()
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

-- The one beat that can take a saved board (prologue.continue passes it); every other thunk ignores
-- its argument.
local function overworld(quest)
    return function(resume) prologue.runOverworld(quest, resume) end
end

-- ---------------------------------------------------------------------------
-- Sequencer
-- ---------------------------------------------------------------------------

-- Build the ordered beat list. Held as a builder so a fresh New Game always starts clean.
local function buildBeats()
    return {
        -- THE SETTING, THEN THE NAME, THEN THE FLOOR (2026-10-16). Etrian Odyssey's order: a city built
        -- around its labyrinth is narrated first, over nothing, because the player has to know why anyone
        -- goes down before the first board is worth reading -- the old opening dropped them onto a lane
        -- with no reason to care. Then the avatar is named (character creation, back at the front where
        -- it used to be), and then the first fight, on floor one of the rift. The narration says nothing
        -- of Rowan or Xin: only the city, the rift, and that you mean to make a name.
        scene("conversation_prologue_opening"),
        function() State.switch(require("states.character_creation")) end,
        action(function() Player.recruit(Player.active, "character_rowan") end), -- Rowan joins for the fight
        battle(VILLAGE_MAP),
        -- THE BEAT AFTER THE FIRST WIN. It used to open the Roll here and say the trip was for the class
        -- requirements; both are gone (2026-10-23). Act 0 banks nothing toward a class (`classCredit =
        -- false` on every prologue fight), and the avatar's first class is Rowan's recommendation, picked
        -- in the city once the Champion is down (states/hub.lua's arrival). Played with `deferJoins` so
        -- Rowan's join banner still folds onto the map's opening, where conversation_prologue_ruins'
        -- header says it lands.
        function()
            require("models.conversation").play("conversation_prologue_classes", prologue.next,
                nil, { deferJoins = true })
        end,
        -- THERE IS NO SCENE BEAT BETWEEN THE FIGHT AND THE MAP. One stood here --
        -- `conversation_prologue_flee`, played over a plain backdrop -- and it is deleted; its lines
        -- moved into the sweep's own opening (conversation_prologue_ruins), which plays over the map
        -- the instant it appears. One screen less between the first fight and the first map.
        --
        -- WHICH MOVES THE JOIN BANNER WITH THEM. "[Rowan has joined your Party]" is queued by her
        -- recruit two beats up (models/conversation.lua) and survives the fight because that fight's
        -- tutorial opening plays with `deferJoins` (states/battle.lua): an over-the-board scene refuses
        -- the banner and holds it for the next FULL scene. That is now the overworld opening, which
        -- states/game.lua plays with no `deferJoins`, so Conversation.drainJoins folds it on there.
        -- Every companion is announced this way; the prologue does not special-case its first one.
        overworld(FLIGHT_QUEST),
        -- THE CHAMPION FELLS ROWAN AT ITS LAST STAGE, and this is where that is collected on. The
        -- `fell` response on its relic puts her down by script at 33% (utility_demon_sigil.lua), the
        -- objective's win writes the injury to the ledger (states/game.lua's inflictInjuries), and the
        -- company carries her into the Cathedral -- which is where Xin is, and why she comes.
        --
        -- ...AND THE PROLOGUE ENDS THERE. Xin is NOT recruited here.
        --
        -- She was, for one pass: a Cathedral scene stood between this leg and the hub, the company
        -- carried Rowan in, and the healer standing there left with them. It is deleted because the
        -- injury it was built on stopped being instantaneous. Reaching the city used to set every bone
        -- free (Injury.clear in hub.enter), so the only place an injury could be TALKED about was a scene
        -- wedged in before the city existed -- and the scene had to do the whole job in four lines
        -- because there was no room that could.
        --
        -- There is a room now. The Cathedral's mending (data/buildings/cathedral.lua) arrives the first
        -- time anybody is carried up broken -- which is Rowan, off this fight -- and Xin is met inside
        -- it, standing where healing actually happens. The player walks in holding the problem, meets
        -- the person whose whole kit is that problem, and takes her. That is the same recruit with a
        -- better reason and a room to have it in.
        --
        -- So Rowan stays hurt through the city gate now, which is the point rather than a regression:
        -- the injury is what puts the Ward on the map and what the tutorial sends the player to.
        -- The Champion falls and the prologue ends with it: prologue.next past the last beat opens the
        -- hub, which is the SAME CITY the sweep was fought through -- there is no journey between the
        -- two. The first-visit staging is the hub's (states/hub.lua reads the hubIntro
        -- flag begin() set): the guard scene plays over the city, the Quest Board is coached, and the
        -- Colosseum debut is taken from the board -- arena_debut carries the Saber recruit
        -- (`rewardCharacter`) and the victory scene (`outro = prologue_victory`), so the climax and the
        -- companion are the quest's own reward rather than a line of script a board-taken run would skip.
    }
end

function prologue.next()
    prologue.cursor = prologue.cursor + 1
    local beat = prologue.beats[prologue.cursor]
    if beat then
        -- Stamped, not saved: the next save the beat writes carries it (see prologue.continue).
        if Player.active then Player.active.prologueBeat = prologue.cursor end
        beat()
    else
        -- THE BACKSTOP, not the payment. The Champion pays the exit level where it falls
        -- (runOverworld's onExitOpened), which is where the class screen then opens onto a company
        -- that has actually levelled. This stays because it is the ONE door out of the prologue and
        -- payExit is idempotent: a route that ever reaches the city without passing the capstone --
        -- a beat reordered, a leg cut short in testing -- still arrives on the level Act 0 promises.
        prologue.payExit(Player.active)
        if Player.active then
            Player.active.prologueBeat = nil
            Player.active.activeRun = nil -- the floor-one leg's parked board (states/game.lua)
            -- Written now, or a quit on the city's first frame would load back onto a finished leg.
            Player.save()
        end
        State.switch(require("states.hub"))
    end
end

-- First entry of a New Game: build the avatar, reset the roster to just the avatar (the company is
-- earned through play), and start the beats. The avatar is the blueprint's human; character creation,
-- the beat before the first fight, gives it a name and nothing else.
function prologue.begin()
    local p = Player.active
    local avatar = Character.instantiate("character_avatar")
    -- Nothing has been typed yet on a New Game, so this falls back to the blueprint's "Stranger" -- which
    -- is why no line spoken before the roll may use {name} (tests/prologue_spec.lua holds that).
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

-- PICKING ACT 0 BACK UP FROM A SAVE (states/saves.lua's load, which Continue shares). `beat` is the
-- `prologueBeat` the save carried. The beat is played again from its top -- a fight restarts, a scene
-- replays -- except the floor-one leg, which takes `run` (the board Save.restoreRun rebuilt) and puts
-- the company back on the tile it quit on. Every beat before it already left its mark in the save (Rowan
-- on the roster, the Roll open), so nothing earlier is replayed.
function prologue.continue(beat, run)
    local p = Player.active
    prologue.beats = buildBeats()
    -- Not saved (see begin): a company loaded mid-prologue has still never walked into the city.
    if p then p.hubIntro = "arrival" end
    if run and run.prologue and prologue.beats[beat] then
        prologue.cursor = beat
        if p then p.prologueBeat = beat end
        prologue.beats[beat](run)
        return
    end
    prologue.cursor = math.max(0, (beat or 1) - 1)
    prologue.pendingAdvance = true
    State.switch(prologue)
end

-- Reached from character creation (a fresh New Game -> begin), from resume() after a battle/overworld
-- leg, or from continue() on a load (both pendingAdvance -> advance). A plain flag check suffices.
function prologue.enter()
    -- THE BED THE SCENES ARE PLAYED UNDER, and it used to be silence -- a bare stopMusic() here, the
    -- only one in the game. The reasoning was that the prologue owns no screen of its own, and it was
    -- wrong in the direction that costs the most: this state is the first thing a new player reaches
    -- past the title, so the game's answer to New Game was the music stopping. Worse on the way back
    -- through -- a resume lands here holding `music.victory`, so the scene played over the held street
    -- would have opened under the bed that plays when you win something.
    --
    -- `music.menu` rather than a bed of Act 0's own: it is the game's face, calm and written to sit
    -- under a still screen, which is exactly what a conversation over a plain backdrop is. Its
    -- battles and the overworld leg still set their own on enter, and the final beat hands off to the
    -- hub, so this only ever covers the scene beats. Idempotent, so arriving from the title (already
    -- playing it) does not restart the track.
    require("models.sound").music("music.menu")
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
-- a sweep's worth of kit -- and a level-1 pair with an empty stash reads as a broken city rather than a
-- skipped prologue.
--
-- ONE BEAT PAST THE PROLOGUE, deliberately: the trip through the Inn's door is taken too, which is
-- where Xin joins and where Rowan's injury is set. That is not something Act 0 grants, it is the two
-- clicks every played run makes on arriving, and the button is for reaching a company that can walk
-- down the stair rather than one standing two clicks short of it. The tail of `skip` argues it in
-- place, and states/menu.lua's card says it to whoever presses the button.
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
-- what the sweep was written to give. The GOLD is paid, through Spoils' own arithmetic: a hub is a row
-- of shops, and arriving at them on the starting purse is the one difference that would make the
-- skipped city play differently from the walked-into one.

-- The two gifts the flight's "Choose..." stops hand over, as { item, from }. Authored rather than read
-- out of the scenes because a stop's two branches are not equal to the ladder: the shrine still TRADES
-- (the censer against a heal you feel now), so nothing in its data says which branch the stop exists to
-- teach, and this names it. These are the mechanics the route's own comments name at those two cells:
-- the adjacency aura at stop 2, the adjacency gate at stop 4.
--
-- The survivor's entry reads as a duplicate of the scene and is not one. ONE of her branches teaches
-- Mark Target and the other takes her purse instead, so a walked sweep may or may not carry the gate
-- out of stop 4 -- and a SKIPPED one has no choice to have made. This line is what it takes: the skip
-- hands over the taught branch, so the company that never played Act 0 stands level with the one that
-- heard her out rather than with the one that took the coin.
prologue.SCENE_GIFTS = {
    { item = "utility_wolfsbane_oil", from = "conversation_flight_event_shrine" },
    { item = "ability_mark_target",  from = "conversation_flight_event_survivor" },
}

-- ...and the flags those same choices set. Both of the survivor's branches set this one, so taking it
-- says nothing about which was chosen.
prologue.SCENE_FLAGS = { "met_the_survivor" }

-- THE LEVEL THE COMPANY WALKS OUT OF ACT 0 ON, guaranteed rather than earned.
--
-- The Champion is the last thing the prologue fights and the company leaves it a level up. That is a
-- BEAT, not an accident of arithmetic: four scripted fights that end with the party exactly as they
-- started is a tutorial that never shows the player the thing every other fight in the game is for,
-- and the level-up panel is itself a lesson the prologue is the only place to teach.
--
-- IT HAS TO BE PAID RATHER THAN LEFT TO THE CURVE, and the reason is worth keeping because it is why
-- this constant exists at all. A level costs what a FLOOR pays (Experience.STEP -- the curve is flat
-- now, FFT-style, with all the control in the award), and Act 0 is four fights: about a floor's worth
-- of fighting, so it lands within a whisker of the line either side of it. It used to clear it easily
-- and only because the old triangular table made the first levels nearly free -- eighty experience
-- bought THREE of them, which is three floors' worth of advancement handed over before the rift, and
-- part of why the opening floor read as a formality. Neither accident is a design: one gave too much
-- and the other gives nothing, and both move again the next time the curve does.
--
-- So the prologue states its exit instead. Topped UP to, never granted flat, so the played road and
-- the skip land in the same place whatever the fighting happened to pay, and a company that somehow
-- earned more keeps it.
-- ...AND IT IS THE RIFT'S NUMBER, NOT THE PROLOGUE'S OWN. Act 0 exists to put a company on the first
-- stair, so where it leaves them is a fact about that stair rather than about the tutorial: it is
-- Descent.OPENING_LEVEL, which is what Descent.expectedLevel starts its ramp from. Held as a literal
-- here it drifted the moment Experience.STEP was re-cut -- the same experience that bought level two
-- on the old curve buys four on this one, and nothing would have said so.
prologue.EXIT_LEVEL = require("models.descent").OPENING_LEVEL

-- THE HOLD UNDER THE EXIT (2026-10-22). Act 0's fights pay 48 to 84 a head and a level costs 24, so
-- left to the curve the company was level three after two fights and walked out at four -- three
-- level-ups handed over before the rift. Every prologue fight now banks up to one short of the exit
-- level and no further (`ceiling`, combat.xpCeiling via Experience.credit), and the fight that opens
-- the way out pays the rest on its win (`exit`), so the ONE level-up Act 0 owes lands on the
-- Champion's killing blow, played before the victory panel.
function prologue.xpCap()
    local Experience = require("models.experience")
    local exit = Experience.totalFor(prologue.EXIT_LEVEL)
    return { ceiling = exit - 1, exit = exit }
end

-- What Act 0's fights bank a body: every one of them is held at the ceiling above, and a played
-- prologue reaches it (they pay 48 to 84 a head against a ceiling of 23). The SKIP's stand-in for that
-- income, so a skipped company arrives having "earned" what a played one earned; payExit then tops
-- it up to the exit, exactly as the Champion's win does.
prologue.SKIP_XP = prologue.xpCap().ceiling

-- Bring every body up to the level Act 0 ends on and resolve it, exactly as a won fight resolves
-- experience (states/game.lua's post-fight seam). Idempotent: a body already there is untouched.
function prologue.payExit(player)
    local Experience = require("models.experience")
    local want = Experience.totalFor(prologue.EXIT_LEVEL)
    for _, char in ipairs((player or {}).roster or {}) do
        local have = char.xp or 0
        if have < want then Experience.award(char, want - have) end
        Experience.resolve(char)
    end
end

-- NO TECHNIQUE IS BANKED FOR THE SKIPPED FIGHTS (2026-10-23), because none is banked for the played
-- ones: Act 0's fights teach no class (`classCredit = false`, Combat.awardTechnique). The skip used to
-- estimate ten actions a fight and file them in each body's houses; that estimate is gone with what
-- it was estimating.

-- Apply everything Act 0 grants to `player`, in the order the beats grant it, and leave the city in
-- free play. Called INSTEAD of prologue.begin -- this state never runs.
function prologue.skip(player)
    local Experience = require("models.experience")
    local Encounter = require("models.encounter")
    local Spoils = require("models.spoils")
    local Conversation = require("models.conversation")
    local Tutorial = require("models.tutorial")
    local Item = require("models.item")
    local Building = require("models.building")

    -- ACT 0'S FINDS RIDE INTO THE CITY IN THE BAG, as a played road's do: Player.findsToPack reads
    -- `prologueBeat`, so it is held for the length of this payout and cleared with the rest at the bottom.
    player.prologueBeat = player.prologueBeat or 1

    -- The avatar, built exactly as begin() builds it: the typed name and chosen body when character
    -- creation ran, the blueprint's own "Stranger" and body 1 when it did not -- the skip does not stop
    -- to ask, which is the whole point of it.
    local avatar = Character.instantiate("character_avatar")
    if player.name then avatar.name = player.name end
    prologue.avatar = avatar
    player.roster = { avatar }
    Player.applyAvatarBody(player)

    -- Rowan, met on the first job.
    Player.recruit(player, "character_rowan")
    -- ...and her join banner dropped on the floor. Player.recruit queues "[Rowan has joined your Party]"
    -- for the next scene to play (models/conversation.lua), and the scene it belongs to -- "First Job" -- is
    -- one of the ones being skipped. Left queued it would fold onto whatever the city opens first, which
    -- is a vendor's greeting three buildings later.
    local joins = Conversation.pendingJoins
    for i = #joins, 1, -1 do joins[i] = nil end

    -- WHAT ROWAN HANDS OVER IN THE FIRST STREET, which is the one part of Act 0 that does not land in the
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

    -- Every stop's authored loot: the two teaching chests, and the kit the two objective lessons are
    -- won with. Read off the route rather than re-listed here, so a re-cut ladder moves both at once.
    -- The places on the map AND the fights the walk deals (the `prowl` queue): both are the route.
    local stops = {}
    for _, stop in ipairs(FLIGHT_QUEST.map.encounters.always) do stops[#stops + 1] = stop end
    for _, stop in ipairs(FLIGHT_QUEST.map.encounters.prowl or {}) do stops[#stops + 1] = stop end
    for _, stop in ipairs(stops) do
        for _, id in ipairs(stop.loot or {}) do Player.grantItem(player, id) end
    end

    -- The gifts the two scenes press on you, and the flag they set.
    for _, gift in ipairs(prologue.SCENE_GIFTS) do Player.grantItem(player, gift.item) end
    player.flags = player.flags or {}
    for _, flag in ipairs(prologue.SCENE_FLAGS) do player.flags[flag] = true end

    -- What the sweep pays for the fighting. Each combat stop rolls its gold through the same arithmetic
    -- the fight would have (Spoils.roll at day 1 -- Act 0 is played before the calendar starts), and a
    -- stop that prices its charges PER HEAD pays for all of them: models/encounter_battle.lua counts the
    -- ones still standing, and a skip hands over the run where everybody walked out.
    local function payFight(count)
        Player.addGold(player, Spoils.roll({ count = count, day = 1 }).gold)
    end
    -- Every route entry that fields a composition pays as the fight it is, and the champion at the end.
    for _, stop in ipairs(stops) do
        local def = Encounter.defs[stop.id]
        if def and def.composition then
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
    payFight(#FLIGHT_QUEST.map.objective.composition({ day = 1 }))

    -- The experience those fights pay, resolved into levels through Growth exactly as a won fight
    -- resolves it (states/game.lua's post-fight seam). Awarded after the recruit, so Rowan is not handed
    -- the median of a company that has not earned anything yet.
    for _, char in ipairs(player.roster) do
        Experience.award(char, prologue.SKIP_XP)
        Experience.resolve(char)
    end
    -- ...and the level Act 0 ends on, which the fighting above may or may not have bought. The played
    -- road pays this at its own exit (prologue.next), so both arrive on the same level.
    prologue.payExit(player)

    -- ...and Rowan's recommendation, which the played road owes from the arrival scene on (states/hub.lua):
    -- the avatar's first class is still to be picked, free, in the Armory (Class.pickOwed).
    player.classPick = true

    -- Stop 7 is a plain rest, so the company reaches the gate whole.
    Player.restore(player)

    -- ...EXCEPT ROWAN, WHO IS CARRIED OUT OF THE LAST FIGHT. The Demon Champion fells her by script at
    -- its final stage (models/combat.lua's Combat.spendScriptedFell) and the objective's win writes it to
    -- the ledger, so a company that skipped Act 0 has to arrive carrying the same injury -- and this is
    -- not flavour the skip can decline. The WARD's card is hung on that mark (models/building.lua's
    -- `unlockInjury`), and XIN IS INSIDE THE WARD: a skip without this opens a city with no ward, no
    -- healer, and a party of two against an expedition of four, which is exactly the "broken city rather
    -- than a skipped prologue" this whole function exists to prevent.
    --
    -- Through Injury.inflict rather than by writing the table, because inflict is what sets the one-way
    -- `injured` mark as well (Injury.everInjured), and the mark is what the door actually reads.
    for _, char in ipairs(player.roster) do
        if char.id == "character_rowan" then
            -- BLOOD LOSS BY NAME, never a roll -- the same call the played prologue makes
            -- (states/game.lua's objective branch). A fall deals one of seven kinds now, and the city
            -- this skip is handing over has a Ward card hung on the mark and a coach line pointing at
            -- the dark band on her bar. A skip that rolled her a Shattered Leg would open the same city
            -- with the same room and nothing on the bar to point at.
            require("models.injury").inflict(player, { char }, "injury_blood_loss")
        end
    end

    -- ...AND THE FIRST TRIP THROUGH THE INN'S DOOR IS TAKEN TOO, which is the one beat this function
    -- hands over that Act 0 does not contain. The button exists to put a company at the Gate ready to
    -- walk down, and a played prologue's very next two clicks are the Inn -- Xin joins out of it
    -- (data/buildings/cathedral.lua's `grants`, played by models/counter.lua) and the bone
    -- Rowan came up with gets set. A skip that stops one door short lands a party of two, one of them
    -- hurt, against an expedition of four, so the skip takes those two clicks.
    --
    -- THE INJURY IS STILL INFLICTED ABOVE AND THEN MENDED HERE, in that order, rather than never dealt:
    -- `Injury.everInjured` is the one-way mark the mending is hung on (models/offer.lua's `injury` gate), and it
    -- survives the mending. Skipping the inflict would shut the door on the room the company has just
    -- been through.
    --
    -- Walked the way the door walks it: the scene's flag recorded, the companion read off the blueprint
    -- rather than named again here, and her join banner dropped on the floor -- the scene it would have
    -- folded onto is one of the ones not being played, and left queued it prints over whatever the city
    -- opens first. (The card's seen-mark went with the plaza's coach, which is what it was for.)
    local ward = Building.defs["cathedral"]
    if ward then
        player.flags["intro_cathedral"] = true
        if ward.grants then Player.recruit(player, ward.grants) end
        local wardJoins = Conversation.pendingJoins
        for i = #wardJoins, 1, -1 do wardJoins[i] = nil end
    end
    require("models.injury").mend(player, 1)

    -- ...and the city opens with nothing owed. begin() sets `hubIntro = "arrival"`, which plays Rowan's
    -- scene over the plaza and leaves the mending flagged as this company's first morning
    -- (states/hub.lua). That staging is the tail of the first-time experience this button exists to get
    -- past, so it is not set: the skip lands in the city a played prologue leaves behind.
    player.hubIntro = nil
    player.prologueBeat = nil
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
