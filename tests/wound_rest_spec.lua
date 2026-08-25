-- A WOUND IS MENDED BY A STAY AT THE INN (models/wound.lua's Wound.rest, models/gate.lua's Gate.lodge).
--
-- It used to be settled at a counter for 120 gold, instantly, off a row on the Cafe's list. That is why
-- the ladder in wound.lua never bit: against a 345g median item the whole thing -- the reserve share,
-- Wounded at two, Crippled at three -- came off for pocket change. Raising the price would not have
-- fixed it. A wound you can pay off at a counter costs a decision once and nothing after.
--
-- SO THE PRICE IS A BED. Coin at the door, a day per wound, and the body is OUT OF THE COMPANY while it
-- takes them -- which is the part that actually costs, and the reason the Gate's picker is a real
-- question. A three-wound body is three days of being a company of six instead of seven.
--
-- A FIRST CUT HAD THE BENCH MEND FOR FREE -- everybody who did not walk down healed, automatically --
-- and it is worth recording why that is wrong rather than merely different: a company that repairs
-- itself for standing still asks the player nothing, and it made the Inn redundant on the day it was
-- written. Resting is a thing you arrange and pay for.

local Wound = require("models.wound")
local Gate = require("models.gate")
local Player = require("models.player")
local Descent = require("models.descent")
local Calendar = require("models.calendar")
local Save = require("models.save")

-- Through the real seam rather than by writing the ledger: Wound.inflict sets `player.wounded` too,
-- the one-way mark the city's Inn opens on, and a fixture that poked `wounds` directly would leave
-- every case here testing a state the game cannot be in.
local function hurt(player, id, n)
    for _ = 1, n do Wound.inflict(player, { { id = id } }) end
end

local function company()
    local p = Player.new()
    p.gold = 10000
    return p
end

return {
    {
        name = "the gold mend is gone, and nothing answers in its place",
        fn = function()
            assert(Wound.mend == nil, "a wound is not settled at a counter any more")
            assert(Wound.MEND_COST == nil, "and there is no price on doing so")
        end,
    },
    {
        name = "a bed costs coin at the door, priced by what is being mended",
        fn = function()
            local p = company()
            hurt(p, "character_rowan", 3)
            assert(Gate.lodgePrice(p, "character_rowan") == 3 * Gate.LODGE_PER_WOUND,
                "three wounds is three nights' worth, got " .. Gate.lodgePrice(p, "character_rowan"))

            local before = p.gold
            assert(Gate.lodge(p, "character_rowan"), "the bed is taken")
            assert(p.gold == before - 3 * Gate.LODGE_PER_WOUND,
                "and paid for in full at the door, got " .. p.gold)
            assert(Gate.isLodged(p, "character_rowan"), "and they are in it")
        end,
    },
    {
        name = "the Inn refuses a bed nobody needs, and one nobody can pay for",
        fn = function()
            local p = company()
            local ok, why = Gate.lodge(p, "character_rowan")
            assert(not ok and why == "unhurt", "an unhurt body is not sold a bed, got " .. tostring(why))
            assert(p.gold == 10000, "and is not charged for one")

            hurt(p, "character_rowan", 2)
            p.gold = Gate.lodgePrice(p, "character_rowan") - 1
            local ok2, why2 = Gate.lodge(p, "character_rowan")
            assert(not ok2 and why2 == "gold", "a short purse is refused, got " .. tostring(why2))
            assert(not Gate.isLodged(p, "character_rowan"), "and nobody is put to bed on credit")
        end,
    },
    {
        -- THE COST THAT IS NOT COIN. A lodged body cannot be sent down, so the stay is paid in being
        -- one short -- which is the whole meter.
        name = "a body in a bed is out of the company",
        fn = function()
            local p = company()
            Player.recruit(p, "character_saber")
            hurt(p, "character_rowan", 1)

            local run = Descent.new(p, 7)
            Descent.setParty(run, { "character_rowan", "character_saber" })
            assert(#Descent.party(run, p) == 2, "both are going")

            Gate.lodge(p, "character_rowan")
            local party = Descent.party(run, p)
            assert(#party == 1, "the lodged body is not going, got " .. #party)
            assert(party[1].id == "character_saber", "the other one still is")
        end,
    },
    {
        name = "a day sets one bone, and only for who is in a bed",
        fn = function()
            local p = company()
            hurt(p, "abed", 3)
            hurt(p, "afield", 3)
            p.atInn = { abed = true }

            local mended = Wound.rest(p)
            assert(#mended == 1 and mended[1] == "abed",
                "only the lodged mend, got " .. table.concat(mended, ","))
            assert(Wound.count(p, "abed") == 2, "three becomes two, got " .. Wound.count(p, "abed"))
            assert(Wound.count(p, "afield") == 3,
                "and standing still mends nobody, got " .. Wound.count(p, "afield"))
        end,
    },
    {
        -- A MENDED BODY WALKS OUT ON THE SAME BEAT. Left lodged at zero wounds they would be a bed that
        -- has to be swept up by hand, and a company one short for a reason the screen no longer shows.
        name = "the last wound set is the end of the stay",
        fn = function()
            local p = company()
            hurt(p, "character_rowan", 1)
            Gate.lodge(p, "character_rowan")

            Wound.rest(p)
            local out = Gate.dischargeMended(p)
            assert(#out == 1 and out[1] == "character_rowan", "they are discharged")
            assert(not Gate.isLodged(p, "character_rowan"), "and back in the company")
            assert(p.atInn == nil, "an empty Inn keeps no table behind it")
        end,
    },
    {
        -- Pulled out half-mended, deliberately allowed: a company that suddenly needs a fourth body
        -- should be able to take one back and pay for it in wounds. The coin does not come back.
        name = "checking out early costs the wounds, not the money",
        fn = function()
            local p = company()
            hurt(p, "character_rowan", 3)
            Gate.lodge(p, "character_rowan")
            local afterPaying = p.gold

            Wound.rest(p)
            assert(Gate.checkout(p, "character_rowan"), "they can be taken back")
            assert(Wound.count(p, "character_rowan") == 2, "still carrying two")
            assert(p.gold == afterPaying, "and the bed is not refunded")
        end,
    },
    {
        -- THE CLOCK IS THE PRICE, pinned against the calendar rather than in the abstract: three wounds
        -- is three of forty days, which is the number the design is arguing about.
        name = "a wound costs a day of a forty-day campaign",
        fn = function()
            local p = company()
            local before = Calendar.day(p)
            hurt(p, "character_rowan", 3)
            Gate.lodge(p, "character_rowan")

            local days = 0
            while Wound.count(p, "character_rowan") > 0 do
                Calendar.spend(p)
                Wound.rest(p)
                days = days + 1
                assert(days <= 10, "mending must terminate")
            end
            assert(days == 3, "three wounds cost three days, got " .. days)
            assert(Calendar.day(p) == before + 3, "and the clock moved by three")
            assert(Calendar.DAYS == 40,
                "the campaign is forty days, so that is 7.5% of it -- if this number moves, the "
                    .. "wound cost moved with it")
        end,
    },
    {
        name = "the bed and the ledger both round-trip a save mid-stay",
        fn = function()
            local p = company()
            hurt(p, "character_rowan", 3)
            Gate.lodge(p, "character_rowan")
            Wound.rest(p)

            local back = Save.restore(Save.snapshot(p))
            assert(Wound.count(back, "character_rowan") == 2,
                "two wounds left, got " .. Wound.count(back, "character_rowan"))
            assert(Gate.isLodged(back, "character_rowan"),
                "and they are still in the bed they were paid into")
        end,
    },
}
