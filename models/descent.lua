-- The Descent: a run is a stack of FLOORS with a landing between each, and the landing asks the only
-- question the overworld never used to -- go deeper, or take what you have and leave.
--
-- This module owns the run's SHAPE and nothing else. No love.graphics, no UI, no state switching, so it
-- loads and tests under the headless runner exactly as models/draft_run.lua does (which is the working
-- precedent for a persistent multi-stage run and is worth reading beside this).
--
-- WHY THIS IS SO SMALL. states/game.lua never consults Quest.defs -- it reads `quest.id`, `quest.map`,
-- `quest.sponsor`, `quest.opening/intro/outro/followUp`, `quest.floorLevel` and `quest.endsCampaign` and
-- nothing else. So a SYNTHESIZED floor descriptor is a legal quest, and the entire overworld / battle /
-- spoils / relic / muster stack runs on one unchanged. Descent.floorQuest below is that descriptor; the
-- game state's whole share of this feature is a branch and a call.
--
--   local run = Descent.new(player)
--   State.switch(states.game, Descent.floorQuest(run), prestige, player)
--   -- ... floor clears -> the landing -> Descent.advance(run) -> floorQuest again, or Descent.extract
--
-- WHAT A RUN CARRIES, and the one rule about it: `run` is PLAIN DATA -- ids, numbers, booleans and flat
-- tables. It is serialized whole by models/save.lua, and Save.encode raises on a function value, so a
-- closure that finds its way in here does not fail gracefully, it takes the whole save write down with
-- it. The quest blueprints build `objective.composition` as a closure, which is exactly the sort of
-- thing that could drift in later -- so floorQuest BUILDS the descriptor fresh on every call and the run
-- never stores one. tests/descent_spec.lua pins the round trip.
--
-- STAGE 1 SCOPE. Floors are procedural and every floor ends in a `meet` stair. The sins, the shuffle and
-- the stair guardians land in later stages; the seams they need are marked below.

local Descent = {}

-- THE SEVEN CIRCLES. One per sin, and a sin is not decoration here -- it names the house whose stock
-- the floor pays into, the ground it is fought on, and what stands on the stair.
--
-- The vendor is the JOIN, and it is the reason this table is small. `data/vendors/*.lua` already
-- declares a `sin` and a `class`; states/game.lua already resolves `game.houseMaterial` from
-- `quest.sponsor` through `Vendor.get(...).class`. So a floor naming its vendor gets its material
-- tagging, its shelf and its standing for free, and this table only has to say which vendor is which
-- circle. tests/descent_spec.lua asserts the pairing against the vendor blueprints rather than
-- restating it, so a sin renamed in data cannot leave a stale copy here.
--
-- The BIOME is a reading of the sin rather than a lookup, so it is authored:
--   gluttony  swamp       a place that swallows what walks into it
--   lust      forest      overgrown, fertile, and hard to see out of
--   greed     underworld  the vault below the vault
--   envy      desert      barren ground with a view of somewhere green
--   wrath     volcanic    the obvious one, and it has earned it
--   sloth     tundra      the post nobody came back to
--   pride     castle      a library that outlived every scholar who could read it
--
-- THE SIN ITSELF STANDS ON THE STAIR. Not a strong body of that house's cast -- the general who IS
-- that circle, by name, every time you walk it. Megaera is at the end of Tartarus on your first run
-- and your fortieth; that is the shape.
--
-- This replaced a generic guardian (a dire bear for Gluttony, an inquisitor for Lust) and the
-- difference is the whole reason a circle is worth recognising on a landing. "Below you: Wrath" means
-- nothing if what is down there is a champion and some barbarians. It means everything if it is Ira.
-- The seven are already written, named and statted -- Gula the Unsated, Ira the Unappeased, Luxuria
-- the Unbidden -- each with a kit that reads its own sin as tactics, and each was reachable exactly
-- once per save at the end of a quest line almost nobody finished.
--
-- The `filler` is their honour guard, drawn from the house's own cast and thickening with depth.
-- Named ids rather than an encounter blueprint because none of this is rollable content: there is
-- exactly one boss per circle and the circle chooses it, never a weight.
--
-- ORDERED, and the order is only a canonical listing -- a run reshuffles it (Descent.sinAt). `pairs`
-- over a registry is unspecified, and a run must lay out the same floors from the same seed on any
-- machine.
Descent.SINS = {
    { id = "gluttony", name = "Gluttony", vendor = "hunters_lodge", biome = "swamp",
        guardian = { lead = "character_general_gluttony", filler = "character_dire_bear" } },
    { id = "lust", name = "Lust", vendor = "cathedral", biome = "forest",
        guardian = { lead = "character_general_lust", filler = "character_inquisitor" } },
    { id = "greed", name = "Greed", vendor = "undercroft", biome = "underworld",
        guardian = { lead = "character_general_greed", filler = "character_mammonite" } },
    { id = "envy", name = "Envy", vendor = "alchemist", biome = "desert",
        guardian = { lead = "character_general_envy", filler = "character_homunculus" } },
    { id = "wrath", name = "Wrath", vendor = "colosseum", biome = "volcanic",
        guardian = { lead = "character_general_wrath", filler = "character_champion" } },
    { id = "sloth", name = "Sloth", vendor = "bastion", biome = "tundra",
        guardian = { lead = "character_general_sloth", filler = "character_forsworn_captain" } },
    { id = "pride", name = "Pride", vendor = "arcanum", biome = "castle",
        guardian = { lead = "character_general_pride", filler = "character_battlemage" } },
}

-- How many STOPS a floor's board hosts -- not how many fights. models/overworld.lua's combatShare caps
-- combat at a share of this and re-seats the rest as texture (a rest, a cache, a merchant), so the
-- number here buys density rather than battles.
--
-- Deliberately low for now. The plan's target is a Dream Quest board of 10-12 stops, and that only
-- becomes playable once an ordinary fight is a two-minute skirmish rather than a six-minute set-piece
-- (the skirmish tier). Raising this before that lands would produce a forty-minute floor. One constant,
-- so that stage is a one-line change here.
--
-- The Dream Quest target, now that an ordinary stop is a skirmish rather than a set-piece: the
-- generator's combat share (0.6) turns ten-to-twelve stops into roughly eight fights, and GUARANTEE
-- seats the rests and the relic cache among the rest. About twenty-seven minutes of floor.
Descent.FLOOR_STOPS = { min = 10, max = 12 }

-- CACHES ARE PINNED, and this is the thing the density bump above would otherwise have moved in
-- silence. Overworld.generate derives the cache count from the stop count at about one per two stops,
-- so twelve stops is six caches where four was two -- and a cache is the largest single source of
-- forging material on a board, well above what the fights leave. Measured, a derived twelve-stop floor
-- pays around three Forge rungs of craft and house stock against the one the stage-2 payout rebase was
-- calibrated to (models/spoils.lua). Two or three holds that line at the new density.
Descent.FLOOR_CACHES = { min = 2, max = 3 }

-- WHAT A FLOOR IS MADE OF, which is not what a quest board's leg is made of.
--
-- The generator draws its stops from a weighted pool, and the campaign's authored weights describe a
-- ROADSIDE -- a long walk with fights among the texture. Measured over thirty generated floors, those
-- weights hand a twelve-stop floor 5.2 fights, of which 2.8 are ELITES. The floor lands on its
-- twenty-seven minutes, but by the wrong route: few long fights instead of many short ones, which is
-- the exact trade the skirmish tier was built to reverse. A floor of five fights where three are
-- six-body set-pieces is the old pacing wearing a new board.
--
-- So a floor reweights the same pool. Three rules, and each is a different kind of statement:
--
--   fights keep their authored weights relative to each other -- which wolf, which boar, is a question
--   about the biome and this has no opinion on it;
--
--   an elite is pinned to a FLAT weight instead of the authored `weight = prestige`. That scaling was
--   written for a campaign where prestige is the run's difficulty dial; on a descent it means elites
--   crowd out ordinary fights without limit as the company grows, so by prestige 20 an "ordinary road
--   stop" is a set-piece again. One or two elites a floor is the punctuation; more is the old problem;
--
--   texture is scaled DOWN hard, because a floor already gets its rests and its reliquary from the
--   generator's own guarantees. Every free draw spent on a town is a skirmish the floor does not have.
--
-- Deliberately a transform over Encounter.pool rather than a second pool: eligibility, biome filtering
-- and the ctx-driven weights are all decisions that table already makes correctly, and restating them
-- here would be a second copy to drift.
Descent.ELITE_WEIGHT = 1.5
Descent.TEXTURE_SCALE = 0.2

-- What share of a floor's stops may be fights. The generator's own cap (0.6) is a roadside's share; a
-- floor wants nearly every stop that is not a guaranteed rest or reliquary to be one. Still a CAP -- it
-- re-seats the overflow as texture and never invents fights -- so it works with the weights above
-- rather than instead of them.
Descent.COMBAT_SHARE = 0.75

function Descent.floorPool(ctx)
    local pool = require("models.encounter").pool(ctx)
    local out = {}
    for i, e in ipairs(pool) do
        local weight = e.weight
        if e.kind == "elite" then
            weight = Descent.ELITE_WEIGHT
        elseif e.kind ~= "combat" then
            weight = weight * Descent.TEXTURE_SCALE
        end
        out[i] = { id = e.id, kind = e.kind, name = e.name, weight = weight }
    end
    return out
end

-- The board a floor is fought on, pinned rather than derived. Overworld.generate honours explicit
-- cols/rows ahead of deriveDims, and deriveDims run at twelve stops reaches its 27x19 cap -- one stop
-- per forty-odd tiles, which is the "marathon warren to shuffle a token through" that
-- models/overworld.lua's own header warns against. 15x13 is one stop per sixteen tiles: dense and
-- readable, and NO CHANGE to the generator.
Descent.FLOOR_COLS, Descent.FLOOR_ROWS = 15, 13

-- The enemy-level floor for a given depth: "a fight on this floor is never easier than this". Same
-- meaning the authored `floorLevel` has everywhere else (models/growth.lua's combatantLevel), which is
-- why it can simply ride on the descriptor.
--
-- Two per floor, anchored so floor 7 reads 13 -- the value Quest.SLOT_FLOOR used to hand the deepest
-- quest of a line. An endless descent cannot have a hand-typed ladder, so this replaces that table.
Descent.LEVEL_PER_FLOOR = 2

-- Ids are `descent_f<N>`. Nothing in the engine ever looks a floor up in Quest.defs -- models/save.lua
-- branches on the presence of a stored descent BEFORE it tries Quest.get -- but the prefix keeps a floor
-- id recognisable in a save file and in a log line.
local ID_PREFIX = "descent_f"

-- ---------------------------------------------------------------------------
-- Determinism
-- ---------------------------------------------------------------------------

-- A floor's layout has to reproduce from (seed, floor) alone: the run is saved as a seed and a depth,
-- and a resume re-derives everything from them. So this is a plain integer hash rather than a stateful
-- RNG -- an RNG would have to store its position too, and would drift the moment anything else drew
-- from it. Pure, headless, and identical on every machine.
--
-- Bit ops are avoided on purpose: this is Lua 5.1 (LOVE's interpreter) and it has none. Multiply-and-mod
-- over values that stay well inside a double's exact-integer range does the same job.
local function hash(seed, floor, salt)
    local h = ((seed or 0) % 1000003) * 31 + (floor or 0) * 7919 + (salt or 0) * 104729
    h = (h * 1103515245 + 12345) % 2147483648
    return h
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

-- Start a descent. `seed` is optional and exists so a spec can pin a run; live play rolls one.
--
-- `entry` is left nil here and filled by states/game.lua on the first floor, because the rollback point
-- is a Save.snapshot and this module deliberately knows nothing about the save format. What matters is
-- that it lives on the RUN rather than on the floor: the whole descent is one expedition, so the
-- snapshot is taken once at the top and every floor after it shares the same way back.
function Descent.new(player, seed)
    return {
        floor = 1,
        seed = seed or (os.time() % 1000000),
        -- Taken at the first floor and then carried by reference for the rest of the descent. See above.
        entry = nil,
        -- Quest ids banked but not yet paid out. Nothing writes this until authored floors land; it is
        -- declared here so the shape of a run does not change under models/save.lua later.
        pending = {},
        -- The deepest floor this run has actually cleared, which is what a new depth record is measured
        -- against at extraction. Distinct from `floor`, which is where the party is standing.
        cleared = 0,
        -- Which circles this run has cleared, as { [vendorId] = floors cleared }. It used to be standing
        -- OWED to the houses, banked into the campaign player on the way out; there is no campaign player
        -- to bank into now, so it is simply the run's own record of what it beat and the terminal card
        -- reads it. Still held on the run rather than anywhere durable, and still lost with a wipe.
        standing = {},
    }
end

-- ---------------------------------------------------------------------------
-- The run's company
-- ---------------------------------------------------------------------------

-- Where a descent in progress lives on disk. Its OWN file, never the campaign's -- a run banks nothing
-- into a save and must not be able to touch one. Deleted the moment a run ends (Descent.clearSaved), so
-- what persists here is one unfinished run and never a trace of a finished one.
Descent.FILE = "descent_run.lua"

-- The gold a mustered company walks in with, over and above what it spent at the muster. Small on
-- purpose: the descent's economy is what its floors pay out -- spoils, caches and the overworld's own
-- merchant stops -- and an opening purse that could buy its way past floor one would make the muster
-- the run rather than its first decision.
Descent.OPENING_GOLD = 50

-- A PLAYER-SHAPED PROFILE FOR ONE RUN, and the reason this exists rather than a new shape.
--
-- states/game.lua, states/battle.lua, models/spoils.lua, models/wound.lua and the relic stack all take a
-- `player` and read a dozen fields off it. A descent could have been given its own object and every one
-- of them taught a second shape; instead it gets the shape they already know, built by Player.new and
-- then overwritten where a clean run differs from a new campaign. The entire overworld/battle/spoils
-- stack then runs a descent unchanged, which is the same trick Descent.floorQuest plays on the quest
-- format one layer up.
--
-- WHAT MAKES IT A DESCENT'S rather than a campaign's is one field: `saveFile`. Player.save writes to it,
-- so every existing save point in the game persists this company to the descent's file and none of them
-- can reach `save.lua`. See Player.save for why that beats a per-call-site flag.
--
-- `chars` is the mustered company (models/descent_muster.lua), already instantiated with their authored
-- kits. Required -- there is no default company, because choosing one is the mode's opening move.
function Descent.newProfile(chars)
    local Player = require("models.player")
    local profile = Player.new()

    profile.saveFile = Descent.FILE
    profile.roster = {}
    profile.lastDeployed = {}
    for _, char in ipairs(chars or {}) do
        profile.roster[#profile.roster + 1] = char
        profile.lastDeployed[#profile.lastDeployed + 1] = char.id
    end

    -- A clean run carries in nothing a campaign would have accumulated. Player.new seeds an opening
    -- stash, materials and recipes for a new GAME; a descent's company is the four-to-eight bodies it
    -- was mustered with and whatever the floors hand them.
    profile.stash = {}
    profile.materials = {}
    profile.recipes = {}
    profile.newItems = {}
    profile.gold = Descent.OPENING_GOLD

    -- The campaign's meters, left at their zero. Nothing in a descent moves them any more -- levels come
    -- from what each body does in the fighting now (models/experience.lua) rather than from prestige --
    -- but the fields stay because the shape is Player.new's and Save.snapshot writes all of it.
    profile.completedQuests = {}
    profile.standing = {}
    profile.deepest = 0
    profile.wounds = {}

    return profile
end

-- Is there an unfinished run on disk? Asked by states/descent.lua before it offers a muster.
function Descent.hasRun()
    return require("models.save").exists(Descent.FILE)
end

-- The saved run's company, or nil if there is none (or it is unreadable). The floor stack and board come
-- back on `resumeRun`, exactly as the campaign's Continue reads them (models/save.lua Save.restoreRun);
-- `saveFile` is re-stamped here because Save.snapshot does not write it -- where a file lives is not
-- something to read out of the file.
function Descent.loadProfile()
    local profile = require("models.save").read(Descent.FILE)
    if not profile then return nil end
    profile.saveFile = Descent.FILE
    return profile
end

-- The run is over -- climbed out, wiped, or abandoned. Nothing carries, so the file goes.
function Descent.clearSaved()
    require("models.save").clear(Descent.FILE)
end

-- How deep the party is standing, 1-based. The only number the difficulty ladder reads.
function Descent.depth(run)
    return (run and run.floor) or 1
end

function Descent.floorLevel(run)
    return 1 + (Descent.depth(run) - 1) * Descent.LEVEL_PER_FLOOR
end

-- WHICH SIN THIS FLOOR IS, from a per-run shuffle of the seven.
--
-- A SHUFFLE, not a random pick per floor, and the difference is the whole feature: a pick would let a
-- run draw Wrath three times and never reach Envy, so the first seven floors would stop being a tour
-- of the circles and become a slot machine. Dealt as a permutation instead -- floors 1..7 are the seven
-- sins in some order, exactly once each -- which is what makes re-treading the shallow floors tolerable
-- (it is a different game each run) without making the deep ones a lottery.
--
-- A DESCENT HAS A BOTTOM. Seven circles and then the thing at the end of them, which is what makes
-- this a run rather than a treadmill -- the same shape Hades and Dream Quest use: a fixed way down, a
-- boss that ends it, and a reason to go again that lives in the meta rather than in the depth.
--
-- Derived, never stored. A run is a seed and a depth (Descent.snapshot), and a resume re-derives the
-- whole layout from them; a stored order would be a second copy that could disagree with the seed.
local function shuffledSins(seed)
    local deck = {}
    for i, sin in ipairs(Descent.SINS) do deck[i] = sin end
    -- Fisher-Yates driven by the integer hash rather than by math.random: the RNG is shared with
    -- everything else that draws in a frame, so seeding it here would both perturb them and be
    -- perturbed BY them. Pure in, pure out, identical on every machine.
    for i = #deck, 2, -1 do
        local j = (hash(seed, 0, i) % i) + 1
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- How many floors a whole descent is: the seven circles, and the bottom under them.
Descent.FLOORS = #Descent.SINS + 1

-- Is this the floor the Hollow Crown is standing on? Everything that behaves differently at the end of
-- a run asks this rather than comparing against a number -- the floor count is one constant and this is
-- one reading of it.
function Descent.isBottom(floor)
    return (floor or 1) > #Descent.SINS
end

-- Which circle this floor is. Nil at the bottom, which is not a sin -- it is what the seven of them
-- were in front of.
function Descent.sinAt(run, floor)
    floor = math.max(1, floor or 1)
    if Descent.isBottom(floor) then return nil end
    return shuffledSins(run and run.seed)[floor]
end

-- Which biome this floor wears: its sin's, and the underworld at the bottom -- where the campaign's own
-- ending was always fought (data/quests/quest_the_gate_below.lua). Kept as its own call because the
-- overworld and the landing both ask for the ground by name and neither needs to know what decided it.
function Descent.biomeAt(run, floor)
    local sin = Descent.sinAt(run, floor)
    return sin and sin.biome or "underworld"
end

-- What the landing calls the floor below it: the circle's name, or the thing waiting under all of them.
function Descent.nameOf(run, floor)
    local sin = Descent.sinAt(run, floor)
    return sin and sin.name or "the Hollow Crown"
end

function Descent.floorId(floor)
    return ID_PREFIX .. tostring(floor or 1)
end

function Descent.isFloorId(id)
    return type(id) == "string" and id:sub(1, #ID_PREFIX) == ID_PREFIX
end

-- THE SYNTHESIZED QUEST. Every field here is one states/game.lua actually reads; nothing else is
-- invented, and no field is a function.
--
-- The objective is a `meet` stair: states/game.lua's meet branch (the one the arena debut's walk-out
-- already uses) marks the tile cleared and ends the leg without a fight, which is precisely what a
-- stairwell wants. `ascent = true` puts it on the farthest dead end on the board
-- (Overworld:placeObjectiveAndGates), so the stair is the end of the road rather than a tile you might
-- stumble over on the way to somewhere else.
--
-- From stage 3 this objective becomes a guardian fight instead, and on a sin floor whose house standing
-- has topped out, that house's general. The branch goes here.
-- WHAT STANDS ON THE STAIR. A set-piece drawn from the circle's own house: one lead body, and filler
-- that thickens with depth so floor 7's guardian is a wall where floor 1's is a warning.
--
-- Deliberately NOT an encounter blueprint. The pool in `data/encounters/` is rollable content, weighted
-- and drawn at random against a biome; a guardian is neither -- there is exactly one per floor and the
-- circle chooses it outright. Routing it through the pool would mean authoring seven blueprints that
-- exist only to be picked by a rule that already knows the answer.
--
-- Read as a quest objective's `composition`, so it opens through the unchanged EncounterBattle path at
-- `kind = "objective"` -- which is what puts it at SET-PIECE scale: Arena.CAP_BY_KIND has no entry for
-- an objective, so the cap falls through to the quest's difficulty (Arena.DEFAULT_ENEMY_CAP, nine) and
-- the skirmish tier never touches it. That fall-through was written for the campaign's objectives and
-- is doing the same job here for free.
local function guardianComposition(sin, floorLevel)
    return function()
        local list = { sin.guardian.lead }
        -- Two at the top of the descent, climbing to a full set-piece by the seventh floor. Read off
        -- the floor rather than off prestige: this fight is a statement about how deep the party has
        -- gone, not about how decorated they are (see models/spoils.lua's GOLD_DEPTH_SLOPE for the
        -- same argument about the gold).
        local n = 2 + math.floor((floorLevel or 1) / 3)
        for _ = 1, n do list[#list + 1] = sin.guardian.filler end
        return list
    end
end

-- THE BOTTOM. Lifted whole from data/quests/quest_the_gate_below.lua rather than reinvented: the
-- Hollow Crown, its honour guard, its confrontation scene and the assassinate condition are all
-- authored content that already works, and the campaign reaching the same body by a different road is
-- not a reason to write it twice. What the descent changes is only the way in -- seven circles instead
-- of seven generals' keys.
--
-- The guard thickens with the FLOOR rather than with prestige, like every other stair on the way down.
local function crownComposition(floorLevel)
    return function()
        local list = { "character_demon_lord" }
        for _ = 1, 2 + math.floor((floorLevel or 1) / 4) do list[#list + 1] = "character_champion" end
        return list
    end
end

function Descent.floorQuest(run, player)
    local floor = Descent.depth(run)
    local sin = Descent.sinAt(run, floor)
    local floorLevel = Descent.floorLevel(run)

    if not sin then
        return {
            id = Descent.floorId(floor),
            name = "The Descent — The Hollow Crown",
            description = "The bottom.",
            -- No house holds this floor, so nothing tags its materials. Deliberate: the last floor is
            -- not anybody's errand.
            sponsor = nil,
            floorLevel = floorLevel,
            descent = run,
            -- What states/game.lua reads to know that clearing this objective ENDS the run rather than
            -- opening another landing. Named on the descriptor rather than inferred from the depth, so
            -- the state never has to learn how long a descent is.
            endsDescent = true,
            map = {
                biome = "underworld",
                ascent = true,
                cols = Descent.FLOOR_COLS,
                rows = Descent.FLOOR_ROWS,
                encounters = { min = Descent.FLOOR_STOPS.min, max = Descent.FLOOR_STOPS.max },
                cacheCount = { min = Descent.FLOOR_CACHES.min, max = Descent.FLOOR_CACHES.max },
                keyCount = 0,
                combatShare = Descent.COMBAT_SHARE,
                objective = {
                    name = "The Hollow Crown",
                    -- The only seam the Crown can speak from: by the time an outro runs, an
                    -- assassinate target is already dead.
                    opening = "conversation_gate_below_confront",
                    composition = crownComposition(floorLevel),
                    win = { type = "assassinate", target = "character_demon_lord" },
                },
            },
        }
    end

    return {
        id = Descent.floorId(floor),
        name = "The Descent — " .. sin.name,
        description = "Down.",
        -- The circle's house. states/game.lua resolves `game.houseMaterial` from this through
        -- Vendor.get(...).class, so naming the vendor is the whole of the material tagging: the floor's
        -- caches and every fight on it pay into that house's stock.
        sponsor = sin.vendor,
        -- Which circle this is, for anything that wants to say so without re-deriving the shuffle (the
        -- landing names the one below, and from stage 4 extraction banks standing against it).
        sin = sin.id,
        floorLevel = floorLevel,
        -- The field states/game.lua keys the whole feature off. Carried by reference: the state reads it
        -- to know it is in a descent and to park it on player.activeRun.
        descent = run,
        map = {
            biome = sin.biome,
            ascent = true,
            -- Pinned, all three of them, and each for its own reason -- see the constants.
            cols = Descent.FLOOR_COLS,
            rows = Descent.FLOOR_ROWS,
            encounters = { min = Descent.FLOOR_STOPS.min, max = Descent.FLOOR_STOPS.max },
            cacheCount = { min = Descent.FLOOR_CACHES.min, max = Descent.FLOOR_CACHES.max },
            -- keyCount 0 because a floor is not a lock puzzle: the stair is always reachable.
            keyCount = 0,
            combatShare = Descent.COMBAT_SHARE,
            objective = {
                name = "The Stair Down",
                composition = guardianComposition(sin, floorLevel),
                win = { type = "killAll" },
            },
        },
    }
end

-- Step to the next floor. Records that the floor just left was cleared, which is what the depth record
-- is read from at extraction -- `floor` alone would over-report, since it is where the party is
-- standing rather than what they beat.
function Descent.advance(run)
    if not run then return end
    run.cleared = math.max(run.cleared or 0, run.floor or 1)
    run.floor = (run.floor or 1) + 1
    return run
end

-- The party has cleared a floor and is standing on its landing. Called before the extract-or-descend
-- prompt so both branches agree on what has been beaten.
function Descent.clearFloor(run)
    if not run then return end
    local floor = run.floor or 1
    -- Credit the circle, once. Re-entering a floor cannot happen today (the stair is one-way) but the
    -- guard is cheap and the alternative is a bug that pays double and is invisible in a save file.
    if floor > (run.cleared or 0) then
        local vendor = Descent.sinAt(run, floor).vendor
        run.standing = run.standing or {}
        run.standing[vendor] = (run.standing[vendor] or 0) + 1
    end
    run.cleared = math.max(run.cleared or 0, floor)
    return run.cleared
end

-- WALKING OUT WITH IT. Closes the run and returns the account of it that states/descent.lua's terminal
-- card reads.
--
-- THIS USED TO BANK, AND THE FACT THAT IT NO LONGER DOES IS THE MODE. It wrote standing per house and a
-- new depth record onto the campaign player, and paid a prestige point per floor of record, so a descent
-- was the campaign's progression engine wearing a stair. The descent is a separate game mode now: a run
-- musters its own company at the mouth, and when it ends there is nothing on the other side of it to pay.
-- Climbing out is still the only exit that is not a loss -- it is what makes the landing's question real
-- -- but what it buys is the run finishing rather than a number somewhere getting bigger.
--
-- So what became of the two things it used to bank:
--
--   the depth record   nothing outlives a run, so there is no record to beat. `floors` is reported and
--                      then it is gone.
--   levels             earned in the fighting now, body by body (models/experience.lua), which is what
--                      lets a clean run start at level 1 and still reach the seventh circle.
--
-- The run's FINDS are not touched here and never were: they have been live in the company's stash since
-- the moment they were picked up. What extraction does is drop the rollback point, which is the caller's
-- job (clearRun) because the snapshot lives on player.activeRun. See states/game.lua's rollbackRun for
-- the other half of that rule.
--
-- `player` is still taken, and still only read: the terminal card names the company that walked out.
function Descent.extract(player, run)
    if not (player and run) then return nil end

    -- Which circles this run beat, copied out so the terminal reads a table the run cannot still be
    -- mutating. Ordered by Descent.SINS at the point of display, never by `pairs`.
    local circles = {}
    for vendorId, n in pairs(run.standing or {}) do circles[vendorId] = n end

    local survivors = {}
    for _, char in ipairs(player.roster or {}) do
        survivors[#survivors + 1] = char
    end

    return {
        title = "Climbed Out",
        floors = run.cleared or 0,
        circles = circles,
        gold = player.gold or 0,
        -- The company as it walked out, levels and all -- the one place a run's growth is ever shown
        -- whole, since there is no hub advancement overlay on the other side of this any more.
        company = survivors,
    }
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

-- Plain data only, and deliberately WITHOUT `entry`.
--
-- The rollback point is a full Save.snapshot -- the whole company, its grids and the stash -- and
-- models/save.lua's snapshotRun already writes it once at the run level. Serializing it here as well
-- would put a second copy of the entire player in every save, growing the file by a company per write.
-- So the descent holds `entry` in MEMORY (which is the point: it is what carries the rollback point from
-- one floor to the next, since each floor is a fresh game.enter that would otherwise re-snapshot and
-- quietly bank the last floor's finds) and Save.restoreRun re-attaches it on the way back in.
function Descent.snapshot(run)
    if type(run) ~= "table" then return nil end
    local pending = {}
    for i, id in ipairs(run.pending or {}) do pending[i] = id end
    local standing = {}
    for vendorId, n in pairs(run.standing or {}) do standing[vendorId] = n end
    return {
        floor = run.floor or 1,
        seed = run.seed or 0,
        cleared = run.cleared or 0,
        pending = pending,
        -- Unbanked standing rides in the save, or quitting on floor four and resuming would hand the
        -- three circles below back at zero -- a resume is not an extraction and must lose nothing.
        standing = standing,
    }
end

function Descent.restore(snap)
    if type(snap) ~= "table" then return nil end
    local pending = {}
    for i, id in ipairs(snap.pending or {}) do pending[i] = id end
    local standing = {}
    for vendorId, n in pairs(snap.standing or {}) do standing[vendorId] = n end
    return {
        floor = snap.floor or 1,
        seed = snap.seed or 0,
        cleared = snap.cleared or 0,
        pending = pending,
        standing = standing, -- absent in a save written before circles had houses; an empty table reads the same
        entry = nil, -- re-attached by Save.restoreRun from the run-level copy; see above
    }
end

return Descent
