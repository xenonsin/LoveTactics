-- A WOUND IS PAID IN DAYS NOW (models/wound.lua's Wound.rest).
--
-- It was paid in gold, and barely: Gate.rest cleared the WHOLE roster's ledger for at most a hundred,
-- against a 345g median item. The reserve share, Wounded at two and Crippled at three all came off for
-- pocket change, so the ladder that file is built around never bit. Time cannot be bought off, and a
-- day is the scarcest thing the campaign has (Calendar.DAYS is forty).
--
-- ONE WOUND PER DAY, OFF THE BENCH. Whoever walked down that day was working, and work is not rest --
-- which is the second cost of taking somebody, and the reason a reserve is worth keeping at all.

local Wound = require("models.wound")
local Player = require("models.player")
local Calendar = require("models.calendar")
local Save = require("models.save")

-- Through the real seam rather than by writing the ledger, because Wound.inflict sets more than the
-- count: `player.wounded` is the one-way mark the city's Inn opens on, and a fixture that poked
-- `wounds` directly would leave every case here testing a state the game cannot actually be in.
local function hurt(player, id, n)
    for _ = 1, n do Wound.inflict(player, { { id = id } }) end
end

return {
    {
        name = "a day off the bench sets one bone, and only one",
        fn = function()
            local p = Player.new()
            hurt(p, "a", 3)
            hurt(p, "b", 1)

            local mended = Wound.rest(p, {})
            assert(#mended == 2, "both mend on the same day, got " .. #mended)
            assert(Wound.count(p, "a") == 2, "three becomes two, got " .. Wound.count(p, "a"))
            assert(Wound.count(p, "b") == 0, "one becomes none, got " .. Wound.count(p, "b"))

            -- ...and the cleared entry is GONE rather than left at zero, or the ledger grows forever
            -- with every body that was ever hurt once (models/save.lua drops empty entries).
            assert(p.wounds["b"] == nil, "a mended body leaves no zero behind")
        end,
    },
    {
        -- THE COST OF TAKING SOMEBODY. A body that went down did not rest, so the expedition pays twice:
        -- the day, and the four who do not heal that day.
        name = "whoever went down does not mend that day",
        fn = function()
            local p = Player.new()
            hurt(p, "went", 2)
            hurt(p, "stayed", 2)

            Wound.rest(p, { "went" })
            assert(Wound.count(p, "went") == 2, "work is not rest, got " .. Wound.count(p, "went"))
            assert(Wound.count(p, "stayed") == 1, "the bench mends, got " .. Wound.count(p, "stayed"))

            -- Characters as well as ids, since that is what a party is made of.
            Wound.rest(p, { { id = "went" } })
            assert(Wound.count(p, "went") == 2, "a character is read the same as an id")
        end,
    },
    {
        name = "resting an unhurt company is a no-op, not an error",
        fn = function()
            local p = Player.new()
            assert(#Wound.rest(p, {}) == 0, "nobody to mend")
            p.wounds = nil
            assert(#Wound.rest(p, {}) == 0, "and no ledger at all is not a crash")
        end,
    },
    {
        -- THE LADDER IS THE ONE wound.lua ALREADY OWNS. Mending is the same step down it, so the
        -- debuffs and the reserve come back in the order they were paid for -- three to two loses
        -- Crippled, two to one loses Wounded, one to none gives the whole body back.
        name = "mending walks back down the ladder it was inflicted up",
        fn = function()
            local p = Player.new()
            hurt(p, "x", 3)
            local floor = Wound.healShare(p, "x")

            Wound.rest(p, {})
            local two = Wound.healShare(p, "x")
            assert(two > floor, "two wounds reserve less of the body than three")

            Wound.rest(p, {})
            Wound.rest(p, {})
            assert(Wound.count(p, "x") == 0, "and three days sets three bones")
            assert(Wound.healShare(p, "x") == 1, "the whole body is back, got " .. Wound.healShare(p, "x"))
            assert(Wound.everWounded(p), "but the fact that it happened is one-way")
        end,
    },
    {
        -- THE CLOCK IS THE PRICE. A wait is worth pinning against the calendar rather than in the
        -- abstract: three wounds is three of forty days, which is the number the design is arguing
        -- about and the one a change here would silently move.
        name = "a wound costs a day of a forty-day campaign",
        fn = function()
            local p = Player.new()
            local before = Calendar.day(p)
            hurt(p, "x", 3)

            local days = 0
            while Wound.count(p, "x") > 0 do
                Calendar.spend(p)
                Wound.rest(p, {})
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
        name = "the ledger round-trips a save mid-mend",
        fn = function()
            local p = Player.new()
            hurt(p, "character_rowan", 3)
            Wound.rest(p, {})

            local back = Save.restore(Save.snapshot(p))
            assert(Wound.count(back, "character_rowan") == 2,
                "two wounds left, got " .. Wound.count(back, "character_rowan"))
        end,
    },
}
