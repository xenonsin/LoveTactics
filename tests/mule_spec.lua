-- Tests for THE PACK MULE (models/mule.lua): the cap on what a run can carry out, the verb that makes
-- part of it permanent early, and the trip that verb costs.
--
-- WHAT IS ACTUALLY AT RISK HERE, as with the tally, is not the arithmetic but the SEAMS -- and one of
-- them is load-bearing in a way that would be invisible in play until somebody noticed the campaign had
-- quietly grown a carrying limit: Mule.room answers math.huge outside a descent. Every grant path in
-- the game asks it, so an answer of nought there would silently stop quest rewards, shop purchases and
-- inventory reshuffles from landing. That case is first, and it is the one that must never go red
-- quietly.
--
-- The map control lives in states/game.lua and cannot be driven headlessly, so what is exercised is
-- Mule.dispatch -- which is what that button calls and the only thing it does.

local Mule = require("models.mule")
local Player = require("models.player")
local Save = require("models.save")
local Item = require("models.item")
local Character = require("models.character")
local Descent = require("models.descent")

local function anyItemId()
    local ids = {}
    for id in pairs(Item.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids[1]
end

-- A company standing on a floor with an entry snapshot behind it -- which is the only state in which a
-- mule means anything, since what it carries is the diff against that snapshot (Player.atRisk).
local function companyInRun()
    local player = Player.new()
    local char = Character.instantiate("character_knight")
    player.roster = { char }
    player.stash = {}
    char.inventory = {}
    local entry = Save.snapshot(player)
    local run = { floor = 1, seed = 1, entry = entry }
    player.activeRun = run
    return player, run, char
end

-- Drop `n` finds into the stash, which is what a chest or a fight's loot does.
local function find(player, n)
    local id = anyItemId()
    for _ = 1, n do player.stash[#player.stash + 1] = Item.instantiate(id) end
end

return {
    { name = "outside a descent the mule has no opinion at all", fn = function()
        -- THE CASE THAT MUST NEVER GO QUIETLY RED. Mule.room is asked on grant paths shared with the
        -- campaign; anything but an unbounded answer there would cap a quest's reward items and a shop
        -- purchase, neither of which has ever had a carrying limit.
        local p = Player.new()
        assert(Mule.room(p) == math.huge, "a company with no expedition open carries what it likes")
        assert(Mule.canTake(p, 999), "and any number of things fit")
        assert(not Mule.isFull(p), "an absent mule is never full")
        assert(Mule.load(p) == 0, "and it is carrying nothing, because there is nothing to diff")
        assert(Mule.room(nil) == math.huge, "nil is answerable too, since draw code asks before a save exists")
    end },

    { name = "it carries exactly what the run found", fn = function()
        local p, run = companyInRun()
        assert(Mule.load(p, run) == 0, "a company that has just walked in has found nothing")
        find(p, 3)
        assert(Mule.load(p, run) == 3, "three finds, three slots")
        assert(Mule.room(p, run) == Mule.capacity(p) - 3, "and the room left is the rest of the capacity")
    end },

    { name = "full is full, and the last slot is the one that says so", fn = function()
        local p, run = companyInRun()
        find(p, Mule.CAPACITY - 1)
        assert(not Mule.isFull(p, run), "one short is not full")
        assert(Mule.canTake(p, 1, run), "and one more fits")
        assert(not Mule.canTake(p, 2, run), "but two do not -- a chest is all or nothing")
        find(p, 1)
        assert(Mule.isFull(p, run), "and now it is full")
        assert(not Mule.canTake(p, 1, run), "with nothing more going on it")
        assert(Mule.room(p, run) == 0, "no room at all")
    end },

    { name = "a mule on the road carries nothing, and that is not the same as being full", fn = function()
        -- The two states have the same answer to "can I take this" and DIFFERENT answers to why, which
        -- is the whole reason the readout distinguishes them (states/game.lua's HUD).
        local p, run = companyInRun()
        find(p, 2)
        run.muleAway = 3
        assert(Mule.isAway(run), "it is on the road")
        assert(Mule.room(p, run) == 0, "so nothing fits")
        assert(not Mule.canTake(p, 1, run), "and nothing may be taken")
        assert(not Mule.isFull(p, run), "but it is not FULL -- it is absent, which reads differently")
    end },

    { name = "the trip is counted in won fights and floors at nought", fn = function()
        local run = { floor = 1, seed = 1 }
        run.muleAway = 2
        assert(Mule.fightsAway(run) == 2, "two fights out")
        Mule.noteFight(run)
        assert(Mule.fightsAway(run) == 1, "one fight closer")
        Mule.noteFight(run)
        assert(Mule.fightsAway(run) == 0, "and home")
        assert(not Mule.isAway(run), "which is what home means")
        Mule.noteFight(run)
        assert(Mule.fightsAway(run) == 0, "fighting on does not send it away again")
        assert(Mule.noteFight(nil) == 0, "and a fight outside a descent ticks nothing")
    end },

    { name = "sending it home banks what it carried", fn = function()
        local p, run = companyInRun()
        find(p, 4)
        assert(Mule.load(p, run) == 4, "four finds aboard")
        local ok, carried = Mule.dispatch(p, run, Save.snapshot(p))
        assert(ok and carried == 4, "it leaves with all four, got " .. tostring(carried))
        -- THE BANK IS THE RE-BASELINE. Everything found up to this moment stops being reachable by a
        -- wipe, which is the same operation the ascent stair performs -- and the mule reading empty is
        -- how you can tell it happened.
        assert(Mule.load(p, run) == 0, "and the mule reads empty, because the diff is against the new floor")
        assert(#p.stash == 4, "while the finds themselves are still in the stash, and now permanently")
        assert(Mule.fightsAway(run) == Mule.TRIP, "the trip costs Mule.TRIP fights")
    end },

    { name = "it refuses the two sends that would mean nothing", fn = function()
        local p, run = companyInRun()
        -- An empty mule has nothing to send, and spending the trip for no gain is not a decision a
        -- player can mean -- which is also why the button does not draw in this state.
        local ok, why = Mule.dispatch(p, run, Save.snapshot(p))
        assert(not ok and type(why) == "string", "an empty mule is not sent, and says why")
        find(p, 1)
        assert(Mule.dispatch(p, run, Save.snapshot(p)), "a loaded one goes")
        find(p, 1)
        local twice = Mule.dispatch(p, run, Save.snapshot(p))
        assert(not twice, "and it cannot be sent again while it is already on the road")
    end },

    { name = "the ladder is capacity and nothing else, and it is bought with gold", fn = function()
        local p = Player.new()
        assert(Mule.capacity(p) == Mule.CAPACITY, "a fresh company stands on the first rung")
        assert(Mule.rung(p) == 1, "which is rung one")
        local next_ = Mule.nextRung(p)
        assert(next_ and next_.capacity > Mule.CAPACITY, "and there is somewhere to climb to")

        p.gold = next_.price - 1
        assert(not Mule.upgrade(p), "a company one coin short buys nothing")
        assert(Mule.capacity(p) == Mule.CAPACITY, "and the mule is no wider for having been offered")

        p.gold = next_.price
        assert(Mule.upgrade(p), "and with the price in hand it widens")
        assert(Mule.capacity(p) == next_.capacity, "to the next rung's capacity")
        assert(p.gold == 0, "having spent exactly the asking price")
        assert(Mule.rung(p) == 2, "and the rung is derived from the capacity, never stored beside it")

        -- The top of the ladder offers nothing, which is what stops the card drawing there.
        p.muleCapacity = Mule.RUNGS[#Mule.RUNGS].capacity
        assert(Mule.nextRung(p) == nil, "the widest mule has nowhere left to go")
        assert(not Mule.upgrade(p), "and cannot be sold a rung that does not exist")
    end },

    { name = "the rungs climb in both capacity and price", fn = function()
        -- REPORTED IS NOT ENFORCED: a rung authored out of order would sell a narrower mule for more
        -- money, which is invisible until somebody buys one.
        for i = 2, #Mule.RUNGS do
            assert(Mule.RUNGS[i].capacity > Mule.RUNGS[i - 1].capacity,
                "rung " .. i .. " holds more than the one below it")
            assert(Mule.RUNGS[i].price > Mule.RUNGS[i - 1].price,
                "and costs more than the one below it")
        end
        assert(Mule.RUNGS[1].price == 0, "the rung a company already stands on is never charged for")
        assert(Mule.RUNGS[1].capacity == Mule.CAPACITY, "and it is the base capacity")
    end },

    { name = "the width rides the save and the trip rides the run", fn = function()
        -- TWO HOMES ON PURPOSE (models/mule.lua). The width is a thing the company bought and keeps; the
        -- trip is a thing happening inside one expedition, and a fresh rift must never open with a mule
        -- notionally still halfway home.
        local p = Player.new()
        p.gold = 100000
        Mule.upgrade(p)
        local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
        assert(Mule.capacity(back) == Mule.capacity(p), "the width survives a load")

        local run = Descent.new(Player.new(), 42)
        run.muleAway = 4
        local rerun = Descent.restore(Save.decode("return " .. Save.encode(Descent.snapshot(run), 0)))
        assert(Mule.fightsAway(rerun) == 4, "a resumed run remembers how far out the mule is")

        -- ...and a save from before either existed reads as the base width with the mule standing here.
        local older = Save.restore(Save.snapshot(Player.new()))
        assert(Mule.capacity(older) == Mule.CAPACITY, "an older save has the base mule")
        assert(not Mule.isAway(Descent.restore({ floor = 1, seed = 1 })), "and it is not away")
    end },
}
