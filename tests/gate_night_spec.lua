-- Tests for A NIGHT PASSING (models/gate.lua's Gate.night and Gate.rest): the beat that spends a day,
-- mends one wound off everybody in a bed, and walks out whoever that finished.
--
-- ITS OWN FILE because it is its own claim. tests/gate_spec.lua pins what a night does to a BODY -- what
-- it gives back, what it refuses to give back, what it will not refill -- and every case in here is
-- about the CLOCK instead: who may move it, what moves with it, and what happens at the end of it.
--
-- WHY THE BEAT EXISTS AT ALL. Until this landed, `Calendar.spend` had exactly one caller -- entering a
-- descent (states/game.lua) -- so the only way to spend a day was to walk into a fight. A wound mends by
-- days abed and by nothing else (models/wound.lua's Wound.rest), which meant a company that wiped had to
-- go back down, hurt, to buy the days that would have healed them: the cure on the far side of the
-- thing it was for. The Inn sells the night now, and both callers run the same three steps in the same
-- order.
--
-- Driven through the models; ui/panels/inn.lua is the sentences over the top and cannot run headless.

local Calendar = require("models.calendar")
local Character = require("models.character")
local Descent = require("models.descent")
local Gate = require("models.gate")
local Player = require("models.player")
local Wound = require("models.wound")

-- A company of `n` at a known purse, on day one with the whole calendar ahead of it.
local function company(n, gold)
    local chars = {}
    for i = 1, (n or 1) do
        chars[i] = Character.instantiate(i == 1 and "character_knight" or "character_archer")
    end
    local p = Descent.newProfile(chars)
    p.gold = gold or 5000
    p.day = 1
    return p
end

-- Break `char` `n` times over. Wound.inflict takes a list of bodies and adds one apiece.
local function hurt(p, char, n)
    for _ = 1, (n or 1) do Wound.inflict(p, { char }) end
    return Wound.count(p, char.id)
end

return {
    { name = "a night at the inn spends a day, which is the only thing that mends", fn = function()
        -- THE CASE THE WHOLE FILE IS FOR. Lodge a body, sleep, and the bone is set -- without anybody
        -- having to walk into a descent to make the clock move.
        local p = company(2, 5000)
        local char = p.roster[1]
        assert(hurt(p, char, 2) == 2, "precondition: two bones to set")
        assert(Gate.lodge(p, char.id), "the bed is taken")

        local day = Calendar.day(p)
        local ok, mended = Gate.rest(p)
        assert(ok, "the company can afford the night")
        assert(Calendar.day(p) == day + 1, "a night is a day: the calendar moved")
        assert(Wound.count(p, char.id) == 1, "and one wound came off the body in the bed")
        assert(mended and mended[1] == char.id, "and the night says whose it was")
        assert(Gate.isLodged(p, char.id), "with one still to set, they are still in the room")

        local ok2 = Gate.rest(p)
        assert(ok2, "and a second night follows the first")
        assert(Calendar.day(p) == day + 2, "which spends a second day")
        assert(Wound.count(p, char.id) == 0, "and sets the last bone")
        assert(not Gate.isLodged(p, char.id),
            "whereupon they walk out on the same beat -- a mended body left lodged is a company one " ..
            "short for a reason the screen no longer shows")
    end },

    { name = "a night mends what is in a bed and nothing else", fn = function()
        -- THE REVERSAL THIS RULE EXISTS FOR (models/wound.lua's Wound.rest). A company that repairs
        -- itself for standing still asks the player nothing and makes the Inn redundant on the day it is
        -- written -- so the day only does its work on somebody who was put somewhere.
        local p = company(2, 5000)
        local abed, afoot = p.roster[1], p.roster[2]
        hurt(p, abed, 1)
        hurt(p, afoot, 1)
        assert(Gate.lodge(p, abed.id), "one of them takes a room")

        assert(Gate.rest(p), "the night is bought")
        assert(Wound.count(p, abed.id) == 0, "the one in the bed mends")
        assert(Wound.count(p, afoot.id) == 1,
            "and the one who merely slept here wakes with the bone exactly as broken: buying the night " ..
            "buys the day, and the day is not a surgeon")
    end },

    { name = "going down the stair and waiting at it are the same night", fn = function()
        -- ONE DEFINITION, TWO CALLERS. states/game.lua runs Gate.night on the descend beat and Gate.rest
        -- runs it over the counter; a second copy of the three steps is a second place for the order to
        -- be wrong, and the order is load-bearing (mend before discharge, or a body whose last bone was
        -- set tonight stays lodged until the night after).
        local descend, wait = company(2, 5000), company(2, 5000)
        for _, p in ipairs({ descend, wait }) do
            local char = p.roster[1]
            hurt(p, char, 1)
            assert(Gate.lodge(p, char.id), "the bed is taken")
        end

        -- Read AFTER the beds are taken: lodging is what charges for the room (Gate.lodge), and what is
        -- being compared here is the night itself.
        local purse = { descend = descend.gold, wait = wait.gold }

        Gate.night(descend)                 -- what entering a descent runs
        local ok = Gate.rest(wait)          -- what the counter sells
        assert(ok, "the counter's night is bought")

        for _, p in ipairs({ descend, wait }) do
            assert(Calendar.day(p) == 2, "both spent the day")
            assert(Wound.count(p, p.roster[1].id) == 0, "both set the bone")
            assert(not Gate.isLodged(p, p.roster[1].id), "both walked the mended body out")
        end
        assert(descend.gold == purse.descend, "going down costs no coin at this counter")
        assert(wait.gold < purse.wait, "and the counter's night is paid for")
    end },

    { name = "the night that cannot be bought moves nothing", fn = function()
        -- EVERY REFUSAL LEAVES THE CLOCK WHERE IT WAS, which is the half a spend is most likely to get
        -- wrong: a night that takes the day and then discovers the purse is empty has charged the
        -- scarcest thing in the campaign for nothing.
        local broke = company(2, 0)
        hurt(broke, broke.roster[1], 1)
        local ok, why = Gate.rest(broke)
        assert(not ok and why == "gold", "the room is refused for want of gold")
        assert(Calendar.day(broke) == 1, "and no day was spent on credit")

        local empty = company(1, 5000)
        empty.roster = {}
        local ok2, why2 = Gate.rest(empty)
        assert(not ok2 and why2 == "nobody", "a company of nobody takes no rooms")
        assert(Calendar.day(empty) == 1, "and spends no day doing it")

        -- ...AND THERE WAS A THIRD REFUSAL, "over": forty days, and no night to sell past the last one.
        -- The deadline is retired (models/calendar.lua) and this is what replaced that case -- a company
        -- deep past where the fortieth day used to be can still buy a night, because the alternative was
        -- a beaten company with no way to reach a morning at all.
        local late = company(2, 5000)
        hurt(late, late.roster[1], 1)
        assert(Gate.lodge(late, late.roster[1].id), "the bed is taken")
        late.day = 400
        local before = late.gold
        local ok3 = Gate.rest(late)
        assert(ok3, "the night is sold, however many have passed")
        assert(late.gold < before, "the purse pays for it")
        assert(Calendar.day(late) == 401, "the clock moves")
        assert(Wound.count(late, late.roster[1].id) == 0, "and the bone is set by morning")
    end },

    { name = "a night with nobody abed still costs the day it is sold for", fn = function()
        -- THE HONEST SHAPE OF THE PRICE, stated here because it is what the panel's refusal is built on
        -- (ui/panels/inn.lua greys the row out when nobody is carrying a wound). The model does NOT
        -- refuse a night that mends nobody -- a rule about whether a purchase is worth making belongs to
        -- the surface that shows the player what they are buying, not to the ledger underneath it -- so
        -- what is pinned here is that the cost is real either way, which is precisely why the surface has
        -- to refuse it.
        local p = company(2, 5000)
        local before = p.gold
        local ok, mended = Gate.rest(p)
        assert(ok, "the night is sold")
        assert(#mended == 0, "and it mends nobody")
        assert(p.gold < before, "the coin is gone")
        assert(Calendar.day(p) == 2, "and so is the day")
    end },
}
