-- BOUNTIES: the board's unit of work, and what a day out is spent on.
--
-- A bounty is an ITEM OF WORK the player holds and spends. It names four things and nothing else:
--
--   the ground    which biome the expedition is fought on
--   the tier      how hard, and what grade the find is
--   the boss      one named body standing at the end of it
--   the piece     the specific thing that body gives up
--
-- The fusion this is built on, said once: MONSTER HUNTER names what you go for, PATH OF EXILE decides
-- how you get in and how hard you make it. The piece is the first half. The second half is the AUGMENT
-- (phase 2, not built) -- a danger you add before spending, which raises what the ground pays.
--
-- WHY THE PIECE IS THE WHOLE POINT. Every offer in this game pays the same currency, so failing an
-- expedition costs an amount of gold, which is indistinguishable from succeeding slightly less well.
-- A bounty that names a piece makes a loss cost a NAMED THING -- and nothing else, because the
-- company comes home with everything it walked in with. See docs/economy.md's law: a cost on recovery
-- is a tax on needing to recover, and this file never levies one.
--
-- SPENDING A BOUNTY CONSUMES IT, WIN OR LOSE. What a loss takes is the bounty, the augments staked on
-- it, the consumables burned and the piece -- all of it chosen, none of it permanent. See Bounty.spend
-- and Bounty.held; the stock a company carries is `player.bounties`.
--
-- THE LADDER IS THE GATE, and it is the one structural rule here. There are no seals and no fragments
-- to assemble: finishing a house's bounties is what opens its later ones, exactly as finishing a rank
-- of hunts opens the next. `requires` is that ladder, and a house's general is simply the bounty at
-- the top of it.
--
-- A BOUNTY IS A POSTING OF WORK, AND USUALLY IT IS ALSO THE WHOLE OF THE WORK.
--
-- Two shapes, and the plain one is the common case:
--
--   SYNTHESIZED  the bounty names a ground, a boss and what it pays, and this file builds the map.
--                No quest blueprint exists or is needed. Every rung of every house's ladder is one of
--                these, which is what makes a ladder a data file per rung rather than a writing job.
--   AUTHORED     the bounty names a `quest`, and that blueprint's map, climb and scenes are used
--                instead. The house openers are these -- work that was written before the board was,
--                with set-piece encounters and scenes on both ends.
--
-- The split is what lets the same authored work be posted twice at two tiers without the blueprint
-- learning that tiers exist, and it is why `quest` is optional rather than required: there are seven
-- surviving quest blueprints and a seven-house ladder needs far more rungs than that.
--
-- Pure model -- no love.graphics, no state switching -- so it loads under the headless runner beside
-- models/descent.lua, which is the working precedent for synthesizing a quest descriptor.
--
--   local offered = Bounty.offered(player)
--   State.switch(states.game, Bounty.questFor(offered[1]), nil, player)

local Registry = require("models.registry")
local Quest = require("models.quest")
local Character = require("models.character") -- a boss's own blueprint names it when the posting does not

local Bounty = {}

Bounty.defs = Registry.load("data/bounties", "data.bounties")

-- WHAT A TIER IS WORTH IN LEVELS. `floorLevel` means "this fight is never easier than this, whoever
-- walks into it" (models/quest.lua) -- the one dial that makes depth cost something -- and a bounty's
-- tier is the only thing that sets it, so the ladder and the difficulty curve are one number.
--
-- Five rungs rather than the shelf's six, because a house posts its general at the top and a general
-- is a rung of its own. The numbers are Quest.SLOT_FLOOR's own, sampled at the slots a house's ladder
-- would have sat on, so a bounty at tier 3 is as hard as the old slot 6 -- which is what the enemy
-- blueprints were balanced against and what docs/balance.lua still measures.
Bounty.TIER_LEVEL = { 1, 5, 8, 11, 13 }

-- HOW LONG A SITTING IS, by tier: the stops the generator lays down on the way to the boss.
--
-- Six at the bottom is a Dream Quest level and a Darkest Dungeon medium dungeon, which is the same
-- number docs/overworld.md argues a descent floor from -- and the reasoning transfers exactly, because
-- what both are sizing is one unbroken sitting between two visits to a town. The climb to ten is
-- deliberately shallow: tier already buys difficulty through TIER_LEVEL, the boss, and the guard, so a
-- steep ramp here would charge twice for the same rung.
Bounty.FIGHTS_BY_TIER = { 6, 7, 8, 9, 10 }

-- HOW MANY BODIES STAND WITH THE BOSS, by tier, on top of the boss itself. The honour guard, and the
-- reason a tier 5 apex is a different fight from a tier 1 one even when the same body is at the end
-- of it (which is exactly what P-3's re-posting at a higher tier does).
--
-- Arena.clampComposition keeps one of every distinct id ahead of repeated filler, so the boss can
-- never be trimmed off by an arena cap -- the guard is what a cap is for.
Bounty.GUARD_BY_TIER = { 2, 3, 4, 5, 6 }

local function rung(tbl, tier)
    return tbl[tier or 1] or tbl[#tbl]
end

-- The id prefix a synthesized descriptor wears, so a run stored on disk can tell a bounty it was
-- walking from a quest that has since left the data. models/descent.lua's floor ids take the same
-- shape and for the same reason.
Bounty.ID_PREFIX = "bounty:"

function Bounty.get(id)
    return id and Bounty.defs[id] or nil
end

function Bounty.isBountyId(id)
    return type(id) == "string" and id:sub(1, #Bounty.ID_PREFIX) == Bounty.ID_PREFIX
end

-- The run id for a bounty. Deliberately NOT the underlying quest's id: completing a posting must not
-- mark the blueprint behind it finished, because the same blueprint is also the Bastion companion's
-- recruit ask (models/errand.lua) and a board that silently satisfied a recruitment nobody had walked
-- to would be a bug with no symptom.
function Bounty.runId(id)
    return Bounty.ID_PREFIX .. tostring(id)
end

-- WHAT THE FIGHT AT THE END IS WORTH WALKING TO. Read off the bounty, falling back to the quest's own
-- objective name so a blueprint that has not named a boss still draws something true rather than a gap.
function Bounty.bossName(def)
    if not def then return nil end
    if def.bossName then return def.bossName end
    -- A synthesized posting names the body itself, so its blueprint is the authority.
    local body = def.boss and Character.defs[def.boss]
    if body and body.name then return body.name end
    local src = def.quest and Quest.get(def.quest)
    local obj = src and src.map and src.map.objective
    return obj and obj.name or nil
end

-- THE PIECE: the one item this bounty is FOR, by id. Nil is legal and means a stock bounty -- the
-- other kind of target, where what you came for is material in volume rather than a named thing.
function Bounty.pieceOf(def)
    return def and def.piece or nil
end

function Bounty.tierLevel(def)
    local tier = (def and def.tier) or 1
    return Bounty.TIER_LEVEL[tier] or Bounty.TIER_LEVEL[#Bounty.TIER_LEVEL]
end

-- ---------------------------------------------------------------------------
-- The stock: what the company is carrying
-- ---------------------------------------------------------------------------
--
-- TWO LEDGERS, AND THEY ANSWER DIFFERENT QUESTIONS. Keeping them apart is what makes the loop work:
--
--   player.bounties          HOW MANY of each posting are in hand right now. Spent on taking one,
--                            win or lose. This is the bet, and it is what can run out.
--   player.completedQuests   whether this posting has EVER been finished, under its `bounty:` id.
--                            This is the ladder, and it never un-happens.
--
-- Read the stock to know what may be done today; read the ledger to know what that has opened. A
-- company that finishes a rung and then runs out of the postings above it has not lost the rung.

-- A STANDING OFFER is a house's opening work: always on the board, infinite, and never spent. It is
-- the floor under the whole economy -- a company that burns every posting it holds can always walk to
-- a house and take its opener again, so running dry is a setback and never a lock-out.
--
-- Everything above tier 1 is FOUND, not posted (Bounty.dealDrops). That is the Path of Exile half: the
-- deep work is a thing you hold a finite number of, so pressing on is a bet rather than a menu.
function Bounty.isStanding(def)
    return (def and def.standing) == true
end

function Bounty.count(player, id)
    return ((player and player.bounties) or {})[id] or 0
end

-- Put `n` copies of `id` in hand. Returns the new count, or nil for an id nobody wrote -- a drop table
-- naming a deleted posting must thin the haul rather than take the payout down.
function Bounty.grant(player, id, n)
    if not (player and Bounty.defs[id]) then return nil end
    player.bounties = player.bounties or {}
    local count = (player.bounties[id] or 0) + (n or 1)
    player.bounties[id] = count
    return count
end

-- SPEND ONE, which is what taking a posting off the board costs. Returns true if it was paid.
--
-- A standing offer is free and always succeeds -- it is the house's own work and the house does not
-- run out of it. Everything else must be in hand, and comes out of hand whatever happens next: the run
-- is not refunded for being lost, because a bet you get back is not a bet (docs/economy.md).
function Bounty.spend(player, id)
    local def = Bounty.get(id)
    if not def then return false end
    if Bounty.isStanding(def) then return true end
    local held = Bounty.count(player, id)
    if held <= 0 then return false end
    player.bounties[id] = held - 1
    if player.bounties[id] <= 0 then player.bounties[id] = nil end
    return true
end

-- IS THIS POSTING OPEN? The ladder, and the whole of it: every bounty named in `requires` must have
-- been finished at least once. One with no `requires` is a house's opening work and is always open.
--
-- Fail-open on an unknown id, the same rule Descent.gateFor takes: a prerequisite naming a bounty
-- nobody wrote must leave the board reachable rather than seal a house behind a typo.
function Bounty.isOpen(player, def)
    for _, req in ipairs((def and def.requires) or {}) do
        if Bounty.defs[req] and not Bounty.isDone(player, req) then return false end
    end
    return true
end

-- Has this posting EVER been finished? The ladder's question, not the stock's.
function Bounty.isDone(player, id)
    local completed = (player and player.completedQuests) or {}
    return completed[Bounty.runId(id)] == true
end

-- HOW MANY POSTINGS THIS COMPANY HAS EVER FINISHED. The count the city grows on.
--
-- Counted off the `bounty:` prefix rather than off Player.questsCompleted, which counts EVERYTHING in
-- the ledger -- the prologue's flight, an errand, a quest run some other way. This has to mean "times
-- the company went out on posted work and came back with it done" and nothing else, or the Forge opens
-- because somebody finished the tutorial.
function Bounty.finished(player)
    local n = 0
    for id in pairs((player and player.completedQuests) or {}) do
        if Bounty.isBountyId(id) then n = n + 1 end
    end
    return n
end

-- WHAT IS ON THE BOARD THIS MORNING: every house's standing offer, plus every posting the company is
-- carrying -- filtered to the ones the ladder has opened.
--
-- A FINISHED POSTING DOES NOT LEAVE THE BOARD, and that is the change the stock makes. It leaves when
-- the last copy is SPENT, which is a different and better rule: the same hunt run twice is what a rank
-- ladder is made of, and the second run is what pays the per-boss material rather than the piece
-- again. An infinite re-postable job would be the repeatable quest this project deleted on purpose.
--
-- Entries carry `held` so a surface can say how many are in hand without asking again, and `standing`
-- so it can say which ones never run out.
--
-- Ordered by tier and then by id, because `pairs` is unspecified and a board that dealt its rows in a
-- different order on every visit would be a board nobody can learn.
function Bounty.offered(player)
    local list, seen = {}, {}
    local function add(id, def)
        if seen[id] or not def then return end
        if not Bounty.isOpen(player, def) then return end
        seen[id] = true
        list[#list + 1] = {
            id = id,
            def = def,
            held = Bounty.count(player, id),
            standing = Bounty.isStanding(def),
        }
    end

    -- THE SEASON DECIDES WHICH HOUSES ARE POSTING, and it decides it for STANDING OFFERS ONLY.
    --
    -- A held posting is always on the board whatever the season says, and that is not an oversight: a
    -- bounty in hand was paid for, and a schedule that could make it unspendable would be taking back a
    -- bet the company had already placed. What rotates is the free, infinite work -- so "which house am
    -- I climbing this week" is a real question without anything the player owns going out of reach.
    --
    -- The invariant that keeps this safe is the season table's own (tests/biome_window_spec.lua): at
    -- least three grounds are open every single day, so at least three houses are always posting.
    local BiomeWindow = require("models.biome_window")
    local day = require("models.calendar").day(player)
    local openGround = {}
    for _, id in ipairs(BiomeWindow.openOn(day)) do openGround[id] = true end

    for id, def in pairs(Bounty.defs) do
        if Bounty.isStanding(def) and (not def.ground or openGround[def.ground]) then add(id, def) end
    end
    for id, n in pairs((player and player.bounties) or {}) do
        if n > 0 then add(id, Bounty.defs[id]) end
    end

    table.sort(list, function(a, b)
        local ta, tb = a.def.tier or 1, b.def.tier or 1
        if ta ~= tb then return ta < tb end
        return a.id < b.id
    end)
    return list
end

-- ---------------------------------------------------------------------------
-- The apex trophy: what a repeat kill pays instead of the piece
-- ---------------------------------------------------------------------------
--
-- THE PROBLEM THIS SOLVES, stated plainly because it nearly sank the whole loop: a drop in this game is
-- a WHOLE ITEM, so a second copy of a sword you already own is worth exactly nothing. That does not just
-- make a repeat run pointless -- it undercuts "a piece" as a target, because a posting you would only
-- ever take once is a posting the board may as well delete after you take it.
--
-- MONSTER HUNTER'S PARTS ARE THIS GAME'S MATERIALS, not its items. So: the first kill pays the named
-- piece, once; every kill after pays the house's apex trophy, which the Forge demands for the deep rungs
-- of that house's own gear (models/forge.lua's TROPHY_RUNG). The rare thing you want once, and the parts
-- you farm forever, with no change to models/item.lua at all.
--
-- ONLY THE TWO APEX RUNGS PAY IT. An opener is work; a lieutenant and a general are a body worth coming
-- back for, and the trophy is what makes coming back worth it.
Bounty.TROPHY_BY_TIER = {}
Bounty.TROPHY_BY_TIER[3] = 1 -- a lieutenant
Bounty.TROPHY_BY_TIER[5] = 2 -- ...and a general pays double, because she is twice the walk

-- What this posting pays in trophies on a REPEAT kill, as { materialId = count }, or nil.
--
-- `repeated` is whether this body has gone down before -- Player.hasCompleted under the posting's own
-- run id, which Quest.complete has already stamped by the time this is asked.
function Bounty.trophyFor(def, repeated)
    if not (def and repeated) then return nil end
    local n = Bounty.TROPHY_BY_TIER[def.tier or 1]
    if not n then return nil end
    local id = require("models.material").trophyFor(def.sponsor)
    if not id then return nil end
    return { [id] = n }
end

-- ---------------------------------------------------------------------------
-- Sustain: what finishing a posting puts back on the pile
-- ---------------------------------------------------------------------------

-- HOW MANY POSTINGS A FINISHED ONE PAYS. Above one on purpose: a rate of exactly one makes the stock a
-- treadmill that never grows and never shrinks, and the decision this system exists to create is how
-- much of a growing pile to spend on going deeper. Below one and the pile drains whatever the player
-- does, which makes the standing offers the whole game.
Bounty.DROPS_MIN, Bounty.DROPS_MAX = 1, 2

-- WHAT A FINISHED POSTING PUTS IN YOUR HAND: postings from the same house, at this tier or the next.
--
-- Same house, because that is what makes a house a LADDER you climb rather than a shelf you shop from
-- -- running the Bastion is how you come to hold the Bastion's deeper work. At this tier or one above,
-- because a drop table that could hand over the apex from the opener would delete the climb, and one
-- that never handed over anything higher would cap the company at whatever it started with.
--
-- A STANDING OFFER IS NEVER DROPPED. It is already infinite, so handing one over would be handing over
-- nothing, and it would crowd the pool that is meant to be carrying the climb.
-- THIS RUNG OR THE NEXT ONE, counted in the HOUSE'S OWN RUNGS rather than in raw tiers.
--
-- It used to read `t <= tier + 1`, which quietly assumed every house's tiers were contiguous. They are
-- not and should not be: a ladder is an opener at 1, a lieutenant at 3 and an apex at 5, so a raw
-- tier+1 window found nothing above the opener at all and the stock could never grow past what the
-- board handed out. Ranking the house's own tiers says what the comment always claimed.
function Bounty.dropPool(player, def)
    local sponsor, tier = def and def.sponsor, (def and def.tier) or 1

    -- The distinct tiers this house posts at, ascending -- its rungs.
    local tiers, seen = {}, {}
    for _, other in pairs(Bounty.defs) do
        if other.sponsor == sponsor and not Bounty.isStanding(other) then
            local t = other.tier or 1
            if not seen[t] then seen[t] = true tiers[#tiers + 1] = t end
        end
    end
    table.sort(tiers)

    if #tiers == 0 then return {} end

    -- WHICH RUNG THIS POSTING SITS ON: the highest at or below its own tier. The window is that rung
    -- and the one above it.
    --
    -- A posting BELOW every rung is the standing opener, and it takes the first rung ALONE -- not the
    -- first two. Finishing a house's opener must hand you the next thing up and not a shot at its apex;
    -- the climb is the content, and a drop table that can skip it deletes the climb it is feeding.
    local idx
    for i, t in ipairs(tiers) do
        if t <= tier then idx = i end
    end
    local lo, hi
    if idx then
        lo, hi = tiers[idx], tiers[math.min(idx + 1, #tiers)]
    else
        lo, hi = tiers[1], tiers[1]
    end

    local pool = {}
    for id, other in pairs(Bounty.defs) do
        local t = other.tier or 1
        if other.sponsor == sponsor and not Bounty.isStanding(other)
            and t >= lo and t <= hi and Bounty.isOpen(player, other) then
            pool[#pool + 1] = id
        end
    end
    -- Sorted, because the pool is drawn from by index and `pairs` is unspecified -- an unsorted pool
    -- would deal a different posting from the same seed on a different machine.
    table.sort(pool)
    return pool
end

-- Deal this posting's drops into the company's hand. Returns the ids granted, in order, so the payout
-- can name them -- a bounty that arrives silently is a reward the player never learns they have.
--
-- `roll` is passed in rather than taken from math.random so a caller can pin it: the run hands over its
-- own generator, and a spec hands over a stub.
function Bounty.dealDrops(player, def, roll)
    roll = roll or math.random
    local pool = Bounty.dropPool(player, def)
    if #pool == 0 then return {} end
    local span = Bounty.DROPS_MAX - Bounty.DROPS_MIN + 1
    local n = Bounty.DROPS_MIN + math.floor(roll() * span)
    if n > Bounty.DROPS_MAX then n = Bounty.DROPS_MAX end
    local out = {}
    for _ = 1, n do
        local pick = 1 + math.floor(roll() * #pool)
        if pick > #pool then pick = #pool end
        if Bounty.grant(player, pool[pick], 1) then out[#out + 1] = pool[pick] end
    end
    return out
end

-- WHAT THIS POSTING PAYS, as a list of item ids. The piece leads it, because Quest.complete promotes
-- the promised piece to the front of the payout and the panel marks that row -- see there for why.
function Bounty.paysItems(def)
    if not def then return nil end
    if def.quest then
        -- AUTHORED WORK KEEPS ITS OWN REWARDS WHOLE. The piece is a headline, not a narrowing --
        -- dropping the rest would strand items on a shelf that promises them and never sells them
        -- (tests/obtainable_spec.lua).
        local src = Quest.get(def.quest)
        return src and src.rewardItems
    end
    local out = {}
    if def.piece then out[#out + 1] = def.piece end
    for _, id in ipairs(def.alsoPays or {}) do out[#out + 1] = id end
    return #out > 0 and out or nil
end

-- THE FIGHT AT THE END, built from the boss and the tier and nothing else.
--
-- A FUNCTION rather than a list, because the guard is sized off the tier at resolve time and because
-- that is the shape every other objective in the game already takes (Arena.resolveComposition accepts
-- either). It closes over plain numbers and ids only -- no player, no run -- so the descriptor stays
-- rebuildable from the blueprint alone, which is what lets a saved run resume onto one.
local function bossComposition(def)
    local tier = def.tier or 1
    local boss = def.boss
    local guard = def.guard or {}
    local count = def.guardCount or rung(Bounty.GUARD_BY_TIER, tier)
    return function()
        local list = {}
        if boss then list[#list + 1] = boss end
        -- Cycled rather than drawn at random: a posting must lay out the same fight every time it is
        -- taken, or the board would be promising something it cannot describe.
        if #guard > 0 then
            for i = 1, count do list[#list + 1] = guard[((i - 1) % #guard) + 1] end
        end
        return list
    end
end

-- THE MAP A SYNTHESIZED POSTING IS FOUGHT ON. Everything the overworld generator needs and nothing it
-- does not: a ground, a stop count, and one end.
--
-- `ascent` puts the objective on the farthest dead end there is -- the end of the road, the last thing
-- -- which is the shape a hunt wants: the body you came for is not something you bump into on the way
-- past. It is what the authored openers already set for the same reason.
local function synthesizeMap(def)
    local tier = def.tier or 1
    local fights = def.fights or rung(Bounty.FIGHTS_BY_TIER, tier)
    return {
        biome = def.ground,
        ascent = true,
        encounters = { min = fights, max = fights },
        keyCount = 0,
        objective = {
            name = Bounty.bossName(def),
            composition = bossComposition(def),
            win = { type = "assassinate", target = def.boss },
        },
    }
end

-- THE EXPEDITION, as an ordinary quest object.
--
-- Everything downstream -- models/overworld.lua, the encounter pool, the arena, the save -- reads
-- `quest.id`, `quest.map`, `quest.sponsor`, the scene fields and `quest.floorLevel`, and nothing else.
-- So a synthesized descriptor is a legal quest and the entire board / battle / spoils stack runs on one
-- unchanged. This is models/descent.lua's Descent.floorQuest trick, applied one level up.
--
-- THE BLUEPRINT IS NEVER MUTATED. An authored posting's `map` is copied before the ground is stamped on
-- it, because data/quests/*.lua are immutable blueprints (CLAUDE.md) and a posting that wrote its biome
-- into the shared def would re-point every other posting of the same work.
--
-- REBUILDABLE FROM THE ID ALONE, which models/save.lua depends on: a run stores `bounty:<id>` and
-- restores by calling this again. So nothing here may close over a player or a run.
function Bounty.questFor(entry, player)
    local id = type(entry) == "table" and entry.id or entry
    local def = (type(entry) == "table" and entry.def) or Bounty.get(id)
    if not def then return nil end

    local src = def.quest and Quest.get(def.quest)

    local map
    if src then
        map = {}
        for k, v in pairs(src.map or {}) do map[k] = v end
        -- The posting decides WHERE. One that names no ground keeps the blueprint's own.
        map.biome = def.ground or map.biome
        -- THE OBJECTIVE IS COPIED TOO, and this is not tidiness. A stake reaches into it
        -- (models/augment.lua wraps its composition to stand more bodies at the end), and for an
        -- authored posting `src.map.objective` is the BLUEPRINT'S OWN table -- shared with every other
        -- run of that work. Augmenting one run would otherwise leave those extra bodies standing there
        -- for every future run of it, including unaugmented ones.
        if type(map.objective) == "table" then
            local obj = {}
            for k, v in pairs(map.objective) do obj[k] = v end
            map.objective = obj
        end
    else
        map = synthesizeMap(def)
    end

    return {
        id = Bounty.runId(id),
        -- A POSTING MAY BE FINISHED MORE THAN ONCE, which is what the whole first-kill/repeat-kill split
        -- rests on -- so it must not trip Quest.complete's double-payout guard, which refuses a second
        -- payout under an id already in the ledger.
        --
        -- WHAT STOPS A DOUBLE PAYOUT INSTEAD, because that guard was doing a real job: the posting was
        -- SPENT to get here (Bounty.spend), so a second payout needs a second copy in hand; and the
        -- objective tile clears when it is taken, so nothing re-fires it inside one expedition. The bet
        -- is the guard now, and it is a better one -- it costs something rather than merely refusing.
        repeatable = true,
        name = def.name or (src and src.name) or id,
        description = def.description or (src and src.description),
        -- The house that posted it. states/game.lua resolves `game.houseMaterial` through
        -- Vendor.get(...).class, so naming the vendor is the whole of the material tagging.
        sponsor = def.sponsor or (src and src.sponsor),
        -- The difficulty floor, off the tier and nothing else. See Bounty.TIER_LEVEL.
        floorLevel = Bounty.tierLevel(def),
        -- Scenes ride the blueprint, because they are written about the WORK rather than the posting.
        -- A synthesized posting has none, and that is correct rather than a gap: it is a hunt, and the
        -- board already said everything there is to say about it.
        intro = src and src.intro,
        outro = src and src.outro,
        opening = src and src.opening,
        rewardGold = def.gold or (src and src.rewardGold),
        rewardItems = Bounty.paysItems(def),
        rewardMaterials = def.rewardMaterials or (src and src.rewardMaterials),
        -- THE BODY THE WORK EARNS, if it earns one. Carried but never ADVERTISED: the board promises
        -- gear and a companion arrives through the outro and the join banner, which is where the
        -- surprise belongs (ui/panels/bounty_board.lua deliberately does not read this). Without it the
        -- Colosseum's opener -- which is how Saber joins -- would pay a fight and silently drop her.
        --
        -- Safe on a standing offer, which can be taken again and again: Player.recruit refuses a
        -- duplicate, so the second run pays the work and not a second copy of the person.
        rewardCharacter = src and src.rewardCharacter,
        map = map,
        -- WHAT THE POSTING ITSELF SAID, carried so the payout and the save can name it without
        -- re-reading the blueprint. Plain data: it rides in a save and Save.encode raises on a function.
        bounty = {
            id = id,
            tier = def.tier or 1,
            ground = map.biome,
            piece = Bounty.pieceOf(def),
            boss = Bounty.bossName(def),
            -- WHAT A STAKE STANDS MORE OF AT THE END. models/augment.lua's `guard` term repeats this
            -- body; a posting that names no guard simply cannot be augmented on that axis, and the
            -- board says so rather than charging for nothing.
            guard = def.guard and def.guard[1] or nil,
        },
    }
end

-- THE EXPEDITION, WITH A STAKE ON IT. The one call a surface makes: it knows the posting and what the
-- player chose to stake, and everything else is this file's and models/augment.lua's business.
--
-- Separate from questFor rather than a fourth argument to it, because questFor is also what a SAVE
-- resumes through (models/save.lua) -- and a resume must rebuild the descriptor exactly as it was,
-- stake included, from data that rode in the snapshot rather than from a fresh choice.
function Bounty.stakedQuestFor(entry, player, staked)
    local quest = Bounty.questFor(entry, player)
    if not quest then return nil end
    if staked and #staked > 0 then
        quest = require("models.augment").apply(quest, staked)
    end
    return quest
end

-- ---------------------------------------------------------------------------
-- The seven ladders, derived
-- ---------------------------------------------------------------------------
--
-- EVERY HOUSE'S UPPER RUNGS ARE DERIVED FROM THE CIRCLE TABLE, and this is P-4 of the loop plan doing
-- its work: the seven circles become the seven houses' ladders. `Descent.SINS` already names, per sin,
-- the house that owns it, the ground it is fought on, the lieutenant that holds its middle and the
-- general at the end -- and `Descent.DROPS` already names what each of those two pays for being put
-- down. That is a whole ladder per house, authored, sitting in a table the rift was the only reader of.
--
-- DERIVED RATHER THAN WRITTEN OUT because fourteen files differing only in four ids is fourteen chances
-- to drift, with no single place to read the shape off. The same argument that keeps Quest.SLOT_FLOOR a
-- table rather than seventy hand-typed numbers. Adding a rung to every house is an edit here; adding one
-- to a single house is a data file, and a data file always wins (see the guard below).
--
-- WHAT IS *NOT* DERIVED, deliberately: the opener. Each house's tier-1 posting is a real file pointing
-- at real authored work with real scenes on both ends, because that is the one rung a player meets
-- before they know what a house is.
--
-- THE CEILING, declared so a reader knows what this can produce: TWO rungs per house, never more, for
-- HOUSES_WITH_LADDERS houses. Fourteen postings, and the count is pinned in tests/bounty_spec.lua.
Bounty.DERIVED_PER_HOUSE = 2

-- WHERE THE TWO DERIVED RUNGS SIT. Named rather than written as literals because the gap between them
-- is the point: a lieutenant at 3 and an apex at 5 leaves a ladder reading 1 / 3 / 5, so each rung is a
-- real step rather than the next number along -- and Bounty.dropPool counts RUNGS rather than tiers for
-- exactly this reason.
Bounty.TIER_LIEUTENANT = 3
Bounty.TIER_APEX = 5

-- NO DESCRIPTION IS INVENTED FOR THESE. A posting may carry one and the openers do; these carry none,
-- and the board draws the block only when there is one. Fourteen lines of generated flavour would be
-- fourteen lines nobody wrote -- the game's words are authored, and a hunt whose whole readout is the
-- house, the ground, the level, the body and the piece is already complete without prose.

local function deriveLadders()
    local ok, Descent = pcall(require, "models.descent")
    if not ok or not Descent or not Descent.SINS then return end

    -- The standing opener each house posts, by vendor. It is what a lieutenant's rung requires, so the
    -- ladder starts where the authored work does.
    local openerOf = {}
    for id, def in pairs(Bounty.defs) do
        if Bounty.isStanding(def) and def.sponsor then openerOf[def.sponsor] = id end
    end

    for _, sin in ipairs(Descent.SINS) do
        local drops = (Descent.DROPS or {})[sin.id] or {}
        local minor, guardian = sin.minor or {}, sin.guardian or {}

        -- A body's own blueprint names the posting: Monster Hunter names a hunt after the thing you are
        -- hunting, and so does this. The board row, the objective and the "at the end" line then all say
        -- the same words, which is one thing to learn instead of three.
        local function rung(body, filler, tier, piece, requires)
            if not body then return nil end
            local key = "bounty_" .. sin.vendor .. "_" .. body:gsub("^character_", "")
            -- A REAL FILE ALWAYS WINS. Authoring `data/bounties/<key>.lua` overrides the derived rung
            -- outright rather than colliding with it, so a house that wants a hand-written apex --
            -- scenes, a set-piece climb, a second phase -- simply writes one.
            if Bounty.defs[key] then return key end
            Bounty.defs[key] = {
                name = Bounty.bossName({ boss = body }),
                sponsor = sin.vendor,
                ground = sin.biome,
                tier = tier,
                boss = body,
                guard = filler and { filler } or nil,
                piece = piece,
                requires = requires and { requires } or nil,
                derived = true,
            }
            return key
        end

        local lieutenant = rung(minor.lead, minor.filler, Bounty.TIER_LIEUTENANT,
            (drops.minor or {})[1], openerOf[sin.vendor])
        rung(guardian.lead, guardian.filler, Bounty.TIER_APEX,
            (drops.general or {})[1], lieutenant)
    end
end

deriveLadders()

return Bounty
