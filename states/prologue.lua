-- The prologue: Act 0, the first-time experience (see docs/story.md, "The three acts"). A linear
-- sequence of beats -- scenes, tutorial battles, an overworld leg -- that ends by opening the hub
-- (Act 1). It builds the party through play: the created avatar starts alone, and Rowan (the knight)
-- fights beside them from the first street.
--
-- IT ALL HAPPENS IN ONE CITY, and that city is the capital -- the same one the hub is. A breach opens
-- inside the walls, the avatar is a new hand on a party hired to deal with the fallout, and the
-- overworld leg is the city itself: block by block, clearing what is still loose and pulling out who
-- is left. THERE IS NO JOURNEY. Act 0 does not travel to Act 1; it ends standing in the town the hub
-- opens on. (The earlier premise put the first fight in a frontier market town called Bellmere and
-- spent the overworld on the king's road to the capital. Both are gone. Ids kept the old words --
-- `tutorial_village`, `tutorial_flight`, FLIGHT_QUEST -- because renaming them is a sweep across the
-- specs and the lang file, not a story change.)
--
-- Nothing is sworn to anybody in Act 0. The third companion, Saber, is NOT recruited
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
-- data/characters/character_demon_imp.lua, where those numbers are pinned. The grunt is the step up:
-- it takes several blows, and the lesson deliberately ends with it still standing.
local VILLAGE_MAP = {
    -- Paved, not wooded: this is one of the capital's own lanes, a street away from the breach. Art only on a
    -- curated board -- see the header of data/arenas/tutorial_village.lua, which carries the same
    -- biome and the reason the authored cells are untouched by it.
    biome = "castle",
    layout = "tutorial_village",
    tutorial = "village",
    objective = {
        name = "Hold the Street",
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
    name = "Clear the Streets",
    -- A scene played over the map the instant it appears (states/game.lua fields it on enter). The
    -- overworld is the one screen the prologue hands over with no explanation at all -- markers, fog,
    -- a route -- so Rowan names the aftermath and the errand while the player is looking straight at
    -- it. It also carries the two lines that used to be a scene beat of their own between the fight
    -- and the map, and the join banner with them -- see that file's header.
    opening = "conversation_prologue_ruins",
    map = {
        biome = "castle",
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
                -- Stop 2: THE ADJACENCY AURA -- the Dawn Chrism, granted by the shrine scene's
                -- choices. The first time the 3x3 is ever anything but storage: put it beside a
                -- weapon and the weapon changes (Combat.auraApplies). It was chosen over the charms
                -- that sharpen a number because it pays out on the very next block rather than in
                -- theory -- it makes adjacent kit strike as HOLY, and every demon on this route runs
                -- holy -8 to -4 (character_demon_imp.lua, character_demon_champion.lua). The lesson
                -- and its proof are one step apart.
                { id = "encounter_event", conversation = "conversation_flight_event_shrine" },
                -- Stop 3: FORCED TARGETING -- the Shout, won on the one stop whose objective is other
                -- people's lives. Every rule the route has taught so far is about what the PLAYER may
                -- do; this is the first item that reaches across the board and decides what the ENEMY
                -- does. Taunt (data/status/status_taunt.lua) makes every foe in the diamond come for
                -- the shouter with their default weapon and nothing else.
                --
                -- The stop is built around it and has been since before the ladder was re-cut: this
                -- fight anchors the survivors AHEAD of the party's line, so the demons walk for them
                -- rather than for you, and the bomblet wave at tick 14 charges them and bursts
                -- (character_demon_bomblet). Two bodies cannot physically intercept everything that
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
                { id = "encounter_survivors_defend", loot = { "ability_shout" } },
                -- Stop 4: THE ADJACENCY GATE -- Mark Target, off the survivor scene, and it is handed
                -- over on BOTH branches of that choice on purpose. This is the hard half of the grid:
                -- `requiresAdjacent` leaves the item dead unless a ranged weapon touches it, the
                -- combat panel names what is missing in a red broken-link badge, and the loadout
                -- lights the cells that would fix it green (Combat.adjacencyCandidateCells). The bow
                -- from stop 1 is the only answer in the bag, which is why this stop comes after it.
                -- It used to sit on one branch, so half of all players met the rule and half never
                -- did; a lesson decided by a coin flip is not a lesson.
                { id = "encounter_event", conversation = "conversation_flight_event_survivor" },
                -- Stop 5: TYPED MITIGATION -- a Salamander Hide off the demons blocking the way out.
                -- The party has worn leather and chainmail since the first fight and nothing has ever
                -- said that a coat answers a KIND of blow; this one is blunt enough to be unmissable
                -- ("Does nothing whatever about anything else") and it is not a guess about what the
                -- route fields. Every imp on it swings weapon_cinder_spit, the grunts throw Brimstone,
                -- the grunt's own claws burn now (weapon_rending_claws.lua) and the Champion is met
                -- with an imp and a grunt beside her. Combat.mitigatedDamage sums the resist of every matching
                -- tag, so the coat blunts all of it. The spoils land after the win, so the body it is
                -- actually FOR is the Champion at the end of the trail.
                { id = "encounter_survivors_extract", loot = { "armor_salamander_hide" } },
                -- Stop 6: the last chest before the gate, and ONE lesson -- RENEWAL, a status you
                -- WANT. Everything Act 0 has taught about statuses so far is a wound (Burn, Stun,
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
            -- ONE IMP AND ONE GRUNT, not two imps. An imp has 14 health for a stated reason -- it dies
            -- to one stroke of the starting sword (character_demon_imp.lua argues the number) -- which
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
                return { "character_demon_champion", "character_demon_imp", "character_demon_grunt" }
            end,
            win = { type = "assassinate", target = "character_demon_champion" },
            -- THE CHAMPION STANDS ON THE WAY OUT. Clearing this does not end the leg: the tile it was
            -- holding becomes the road to the city and the company is put back on the map in front of
            -- it, exactly as a circle's guardian opens its stair (models/descent.lua's
            -- Descent.openStair) rather than descending on the killing blow.
            --
            -- WHAT THAT BUYS is the one beat Act 0 had nowhere to put. The kill is where the company
            -- reaches level 2 (prologue.EXIT_LEVEL), and a leg that cut to the city on the same frame
            -- had no moment in which to say so -- the level-up landed in a loading screen. Back on the
            -- map there is a board to stand on, a party strip showing the new level, and a class
            -- screen that has just opened (Descent.markClassesOpen). The road is then the player's own
            -- step, taken when they are finished reading.
            opensExit = { kind = "road", name = "The Road to the City" },
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
function prologue.runOverworld(quest)
    local p = Player.active
    Player.restore(p)
    State.switch(require("states.game"), quest, nil, p, prologue.resume)
    -- ...and what Act 0 owes itself the moment the Champion falls, which is BEFORE the leg ends.
    -- The capstone opens the road rather than the city (the objective's `opensExit`), so the company
    -- is put back on the map with a class screen to read -- and it has to be holding the level that
    -- makes reading it worth anything. Set after the switch because game.enter clears it.
    local game = require("states.game")
    game.onExitOpened = function() prologue.payExit(Player.active) end
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
        -- THE FIRST BEAT IS THE FIGHT, and there is deliberately no scene in front of it. A five-line
        -- visual-novel opening (`conversation_prologue_intro`) stood here and is deleted; everything it
        -- said is said over the board instead, by the fight's own opening scene. See
        -- data/conversations/prologue/conversation_prologue_village.lua for what moved and what went.
        -- So a New Game reaches a tactics board on the click after the name is typed.
        action(function() Player.recruit(Player.active, "character_rowan") end), -- Rowan joins for the fight
        battle(VILLAGE_MAP),
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
        -- objective's win writes the wound to the ledger (states/game.lua's inflictWounds), and the
        -- company carries her into the Cathedral -- which is where Xin is, and why she comes.
        --
        -- ...AND THE PROLOGUE ENDS THERE. Xin is NOT recruited here.
        --
        -- She was, for one pass: a Cathedral scene stood between this leg and the hub, the company
        -- carried Rowan in, and the healer standing there left with them. It is deleted because the
        -- wound it was built on stopped being instantaneous. Reaching the city used to set every bone
        -- free (Wound.clear in hub.enter), so the only place a wound could be TALKED about was a scene
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
        -- the wound is what puts the Ward on the map and what the tutorial sends the player to.
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
        beat()
    else
        -- THE BACKSTOP, not the payment. The Champion pays the exit level where it falls
        -- (runOverworld's onExitOpened), which is where the class screen then opens onto a company
        -- that has actually levelled. This stays because it is the ONE door out of the prologue and
        -- payExit is idempotent: a route that ever reaches the city without passing the capstone --
        -- a beat reordered, a leg cut short in testing -- still arrives on the level Act 0 promises.
        prologue.payExit(Player.active)
        State.switch(require("states.hub"))
    end
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
-- where Xin joins and where Rowan's wound is set. That is not something Act 0 grants, it is the two
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
    { item = "utility_dawn_chrism",  from = "conversation_flight_event_shrine" },
    { item = "ability_mark_target",  from = "conversation_flight_event_survivor" },
}

-- ...and the flags those same choices set. Both of the survivor's branches set this one, so taking it
-- says nothing about which was chosen.
prologue.SCENE_FLAGS = { "met_the_survivor" }

-- What Act 0's four fights pay a body, measured rather than chosen: a two-body company takes all four,
-- and simulated through models/autobattle that is about 48 a head with real play landing nearer 84.
-- This is the SKIP's stand-in for that income, so a skipped company arrives having "earned" what a
-- played one earned. It is not what decides the level -- see prologue.EXIT_LEVEL.
prologue.SKIP_XP = 80

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
prologue.EXIT_LEVEL = 2

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
-- other five, and it no longer even brushes them: the sweep used to hand over one opener per class and
-- now hands over one item MECHANIC per stop (see FLIGHT_QUEST), so a body reaches the city holding what
-- it actually swung rather than a shelf of borrowed houses. Either way the answer here is unchanged --
-- carrying a class's item is not swinging one, and a played Act 0 does not open those doors either.
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
    local Building = require("models.building")

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
    local stops = FLIGHT_QUEST.map.encounters.always
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
    -- Counted rather than typed, because the technique below is priced per fight: the first street to
    -- start with, a stop for every route entry that fields a composition, and the champion at the end.
    -- A route that gains or loses a fight moves both payouts without either figure being touched.
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
    -- ...and the level Act 0 ends on, which the fighting above may or may not have bought. The played
    -- road pays this at its own exit (prologue.next), so both arrive on the same level.
    prologue.payExit(player)

    -- Stop 7 is a plain rest, so the company reaches the gate whole.
    Player.restore(player)

    -- ...EXCEPT ROWAN, WHO IS CARRIED OUT OF THE LAST FIGHT. The Demon Champion fells her by script at
    -- its final stage (models/combat.lua's Combat.spendScriptedFell) and the objective's win writes it to
    -- the ledger, so a company that skipped Act 0 has to arrive carrying the same wound -- and this is
    -- not flavour the skip can decline. The WARD's card is hung on that mark (models/building.lua's
    -- `unlockWound`), and XIN IS INSIDE THE WARD: a skip without this opens a city with no ward, no
    -- healer, and a party of two against an expedition of four, which is exactly the "broken city rather
    -- than a skipped prologue" this whole function exists to prevent.
    --
    -- Through Wound.inflict rather than by writing the table, because inflict is what sets the one-way
    -- `wounded` mark as well (Wound.everWounded), and the mark is what the door actually reads.
    for _, char in ipairs(player.roster) do
        if char.id == "character_rowan" then
            require("models.wound").inflict(player, { char })
        end
    end

    -- ...AND THE FIRST TRIP THROUGH THE INN'S DOOR IS TAKEN TOO, which is the one beat this function
    -- hands over that Act 0 does not contain. The button exists to put a company at the Gate ready to
    -- walk down, and a played prologue's very next two clicks are the Inn -- Xin joins out of it
    -- (data/buildings/cathedral.lua's `grants`, played by models/counter.lua) and the bone
    -- Rowan came up with gets set. A skip that stops one door short lands a party of two, one of them
    -- hurt, against an expedition of four, so the skip takes those two clicks.
    --
    -- THE WOUND IS STILL INFLICTED ABOVE AND THEN MENDED HERE, in that order, rather than never dealt:
    -- `Wound.everWounded` is the one-way mark the mending is hung on (models/offer.lua's `wound` gate), and it
    -- survives the mending. Skipping the inflict would shut the door on the room the company has just
    -- been through.
    --
    -- Walked the way the door walks it: the scene's flag and the card's seen-mark recorded, the
    -- companion read off the blueprint rather than named again here, and her join banner dropped on the
    -- floor -- the scene it would have folded onto is one of the ones not being played, and left queued
    -- it prints over whatever the city opens first.
    local ward = Building.defs["cathedral"]
    if ward then
        player.flags["intro_cathedral"] = true
        Building.markSeen(player, "cathedral")
        if ward.grants then Player.recruit(player, ward.grants) end
        local wardJoins = Conversation.pendingJoins
        for i = #wardJoins, 1, -1 do wardJoins[i] = nil end
    end
    require("models.wound").mend(player, 1)

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
