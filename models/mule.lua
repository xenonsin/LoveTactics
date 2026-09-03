-- THE PACK MULE: how much a company can carry out of the rift, and the one way to make any of it
-- permanent before they leave.
--
-- WHAT IT IS FOR. A descent resets when you walk out of it (models/descent.lua), so everything a run
-- found is provisional until the company surfaces -- and a wipe drops the lot as a guarded pile
-- (Descent.dropPack). That is a good bet and it was an unlimited one: the stash is unreachable
-- underground (Player.takeFromStash is called from the Loadout and the shop, both town screens) but
-- nothing capped what could go INTO it, so the honest play was to hoover up every chest on every floor
-- and carry an unbounded sack into the next fight. A bet with no ceiling is not a bet.
--
-- THREE THINGS, and only the first two are new ground:
--
--   A CAP      the mule holds Mule.CAPACITY items. Full is full: a chest that will not fit stays a
--              chest and its marker stays on the board, which is the mechanic firing rather than a
--              failure -- it is what turns "I found treasure" into "I have to send the mule."
--   A VERB     send it home, from the map, at any time. What it carries lands in the stash and is
--              permanently yours. Mechanically this is the same re-baselining the ascent stair does
--              (states/game.lua's climb-out branch), applied without ending the run.
--   A TIMER    it is gone for Mule.TRIP fights. No capacity at all while it is away: you can fight,
--              you can clear, you cannot loot.
--
-- WHAT IS ON IT IS NOT A LIST. There is no mule inventory and there must not be one. What the mule
-- carries is exactly "everything this run picked up that it did not march in with", which
-- Player.atRisk already computes by DIFFING the live company against the entry snapshot -- item by
-- item, level by level, bound relics excluded, worn gear credited before the loose pile. A second
-- ledger here would be a copy to drift, and every grant seam in the game would have to learn to
-- report to it. Nothing has to report to a diff.
--
-- SO DISPATCHING IS RE-BASELINING, exactly as banking is. Re-taking the entry snapshot makes what is
-- held now the new floor: the diff goes to nought, the mule reads empty, and nothing below can reach
-- what it carried. One operation, two names, and the reason they are the same operation is that they
-- are the same promise.
--
-- ORE DOES NOT RIDE IT. It has its own rule -- a wipe takes three quarters of what the run gained
-- (Player.loseHaul) -- and folding it in would make one dispatch decide everything at once, which is
-- the way to make a decision mushy rather than to make it big.
--
-- GOLD USED TO BE ON THAT LINE BESIDE IT AND CAME OFF, which is the largest thing that has happened to
-- this object. The economy split (models/scrip.lua): the run spends scrip, which is weightless and
-- never comes home, and the CAMPAIGN's coin arrives as valuables -- objects with a price and a weight
-- that have to be carried out and sold (models/valuable.lua). So gold rides the mule now, in the only
-- form it exists in.
--
-- The old note's argument does not survive the change, and it is worth saying why rather than just
-- deleting it. It was written about a NUMBER riding along invisibly: fold coin into the dispatch and
-- one button decides your purse as a side effect of deciding your pack. An object that occupies a slot
-- does not do that. It does not make the dispatch decide more things -- it makes the one thing it
-- already decides legible, because every slot now has a quoted number on it. That is what this cap was
-- built to create and had nothing to fill it with: gear's worth is diffuse ("might I use this?"), and
-- "the idol is 900 and three slots, the censer is 110 and one" is arithmetic a player can actually do.
--
-- SO BULK IS REAL WEIGHT HERE. A valuable declares how many slots it takes (Valuable.bulk) and the load
-- is measured in slots rather than in items -- see Mule.load. Everything that is not a valuable weighs
-- one, exactly as it always did, so no other grant seam in the game changed.
--
-- Pure model: no love.graphics, no state switching, so it loads under the headless runner. The screens
-- over the top are states/game.lua (the map control and the readout) and states/gate.lua (the upgrade).

local Player = require("models.player")

local Mule = {}

-- HOW MANY ITEMS IT HOLDS at the first rung, before anybody has paid to widen it.
--
-- Anchored on Descent.PACK_COMPANY_ITEMS, which is ten -- the size at which a spilled pile stops
-- drawing the circle's vermin and starts drawing a rival company wearing your gear (Descent.packGuard).
-- A FULL MULE LOST SHOULD SIT JUST UNDER THAT LINE: the worst ordinary night is an expensive one that
-- the floor's own small things are standing over, and the company-sized disaster is reserved for a
-- player who upgraded the mule and then pushed anyway. Eight leaves exactly that gap and the upgrade
-- ladder walks straight through it.
Mule.CAPACITY = 8

-- THE UPGRADE LADDER, in gold, bought at the Gate. Index 1 is the base capacity above, so a company
-- that has bought nothing sits at rung 1 and `Mule.RUNGS[1].price` is never charged.
--
-- CAPACITY IS THE ONLY AXIS. A faster mule is the obvious second one and it is deliberately held back:
-- the decision this object exists to create is "send it now, or hold it and risk the lot", and a trip
-- time the player can shrink is a decision that gets mushier every time they pay. Widening the mule
-- makes the same decision BIGGER, which is the direction that stays interesting.
--
-- Priced against an errand's purse (a 250g median, models/gate.lua's own anchor), climbing steeply
-- enough that the last rung is a run's worth of takings rather than an afternoon's.
Mule.RUNGS = {
    { capacity = 8,  price = 0 },
    { capacity = 12, price = 400 },
    { capacity = 16, price = 1100 },
    { capacity = 20, price = 2400 },
}

-- HOW MANY CLEARED FIGHTS IT IS AWAY FOR.
--
-- Descent.floorFights runs six at the top of the stack to nine at the bottom, so five costs most of a
-- shallow floor and about half a deep one -- the mule gets relatively FASTER as the company descends,
-- which is the right direction: the deep floors are where the decision is worth most and where being
-- unable to carry anything for a whole floor would simply stop the player exploring.
--
-- Counted in FIGHTS rather than in stops or in steps. A stop count would make a floor of chests pay the
-- trip off for free, and steps would price it in walking, which is the one thing a player can do
-- without risk. A fight is the unit the rest of the mode is measured in.
Mule.TRIP = 5

-- The capacity this company has bought up to. The base for a player who has never upgraded, and for the
-- nil player a headless caller may hand over.
function Mule.capacity(player)
    return (player and player.muleCapacity) or Mule.CAPACITY
end

-- Which rung `player` stands on, 1..#RUNGS. Derived from the capacity rather than stored beside it, so
-- the two can never disagree about what has been bought.
function Mule.rung(player)
    local cap = Mule.capacity(player)
    for i = #Mule.RUNGS, 1, -1 do
        if cap >= Mule.RUNGS[i].capacity then return i end
    end
    return 1
end

-- The next rung's entry, or nil at the top of the ladder. What the Gate's card offers.
function Mule.nextRung(player)
    return Mule.RUNGS[Mule.rung(player) + 1]
end

-- Buy the next rung. Returns true and the new capacity on success; false and a reason otherwise, so the
-- screen can say WHY rather than merely refusing.
function Mule.upgrade(player)
    if not player then return false, "nobody to sell to" end
    local next_ = Mule.nextRung(player)
    if not next_ then return false, "the mule carries all it can" end
    if (player.gold or 0) < next_.price then return false, "not enough gold" end
    player.gold = player.gold - next_.price
    player.muleCapacity = next_.capacity
    return true, next_.capacity
end

-- ---------------------------------------------------------------------------
-- The trip
-- ---------------------------------------------------------------------------

-- Is the mule away? Read off the RUN rather than the player, because a trip is a thing happening inside
-- one expedition: a descent that ends -- by the stair or by a wipe -- takes the absence with it, and a
-- company should never walk into a fresh rift with a mule still notionally halfway home.
function Mule.isAway(run)
    return ((run and run.muleAway) or 0) > 0
end

-- How many fights until it is back. Zero when it is standing right there.
function Mule.fightsAway(run)
    return math.max(0, (run and run.muleAway) or 0)
end

-- Count a cleared fight against the trip. Called from the one place a fight is resolved as a win, and
-- it is deliberately not called for anything else -- see Mule.TRIP on why the unit is a fight.
function Mule.noteFight(run)
    if not run then return 0 end
    run.muleAway = math.max(0, ((run.muleAway or 0) - 1))
    return run.muleAway
end

-- ---------------------------------------------------------------------------
-- The load
-- ---------------------------------------------------------------------------

-- WHAT THE MULE IS CARRYING, in SLOTS. Zero outside a descent and zero for a run whose entry snapshot
-- is missing, which is the same answer for the same reason: with nothing to diff against there is no
-- such thing as "what this run found".
--
-- SLOTS, NOT ITEMS, since valuables landed. Player.atRisk keys its counts by the live ITEM TABLE, which
-- is what makes the weighing free: the instance is right there to be asked, no id lookup and no second
-- shape for atRisk to return. Valuable.bulk answers one for everything that is not a valuable, which is
-- every item this function has ever counted, so the arithmetic is unchanged for a company carrying gear.
--
-- The count still matters beside the bulk: a partial stack of three one-slot pieces at risk weighs three
-- even though it is one table.
function Mule.load(player, run)
    run = run or (player and player.activeRun)
    local entry = run and run.entry
    if not (player and entry) then return 0 end
    local Valuable = require("models.valuable")
    local n = 0
    for item, count in pairs(Player.atRisk(player, entry)) do
        n = n + count * Valuable.bulk(item)
    end
    return n
end

-- How many slots `what` (an id, a blueprint or an instance) needs. The question every grant seam asks
-- before it takes a find, and the one place that knows the answer is not always one.
function Mule.bulkOf(what)
    return require("models.valuable").bulk(what)
end

-- Will `what` fit? The id-shaped twin of Mule.canTake, so a grant seam does not have to know that
-- weight exists -- it asks about the thing it is holding rather than about a number.
function Mule.canTakeItem(player, what, run)
    return Mule.canTake(player, Mule.bulkOf(what), run)
end

-- How many more items will fit. Zero while the mule is away -- an absent mule is not a full one, but it
-- has exactly the same answer to "can I take this", and the readout is what tells them apart.
--
-- MATH.HUGE OUTSIDE A DESCENT, which is what makes this safe to ask on every grant path in the game.
-- The campaign has no mule and never had a carrying limit; a quest's reward items, a shop purchase and
-- an inventory reshuffle must all go on behaving exactly as they did.
function Mule.room(player, run)
    run = run or (player and player.activeRun)
    if not (run and run.entry) then return math.huge end
    if Mule.isAway(run) then return 0 end
    return math.max(0, Mule.capacity(player) - Mule.load(player, run))
end

-- Will `n` more items fit? Defaults to one, which is what every grant seam asks.
function Mule.canTake(player, n, run)
    return Mule.room(player, run) >= (n or 1)
end

-- Is it full to the brim, with a run open? False while it is away -- that is a different sentence and
-- the surfaces say it differently.
function Mule.isFull(player, run)
    run = run or (player and player.activeRun)
    if not (run and run.entry) then return false end
    if Mule.isAway(run) then return false end
    return Mule.load(player, run) >= Mule.capacity(player)
end

-- ---------------------------------------------------------------------------
-- Sending it home
-- ---------------------------------------------------------------------------

-- SEND IT. Everything the run has found becomes permanently the company's, and the mule is gone for
-- Mule.TRIP fights.
--
-- `snapshot` is models/save.lua's Save.snapshot, passed IN rather than required here: this module is
-- pure model and Save reaches back across the player, so taking it as an argument keeps the dependency
-- pointing one way. states/game.lua is the only caller and it already holds Save.
--
-- Refuses an empty mule. Sending nothing home would spend the trip for no gain, which is not a decision
-- a player can mean -- and the control does not draw where it cannot be used.
function Mule.dispatch(player, run, snapshot)
    run = run or (player and player.activeRun)
    if not (player and run and run.entry) then return false, "no expedition to send it from" end
    if Mule.isAway(run) then return false, "the mule is already on the road" end
    local carried = Mule.load(player, run)
    if carried <= 0 then return false, "the mule is carrying nothing" end

    -- THE BANK, and it is the same operation the ascent stair performs: re-take the rollback point, and
    -- everything found up to this moment stops being reachable by a wipe. The run continues; only its
    -- floor moves.
    if snapshot then
        run.entry = snapshot
        if player.activeRun then player.activeRun.entry = snapshot end
    end
    run.muleAway = Mule.TRIP
    return true, carried
end

return Mule
