-- BONDS (models/bond.lua, approved 2026-10-25). Holds the promises the review rounds made:
--
--   * Rowan and Xin start at D, which lends nothing (an old save's unearned B seed is re-seeded); every other body,
--     companions included, starts at nothing;
--   * the ranks are C / B / A / S, a rank rises one step a won fight by points alone (no once-a-run cap),
--     and the thresholds are paced so a partner reaches S around floor 13 of one run;
--   * a won fight pays each partner its bond deeds (acting together, counted on the board), capped at
--     DEED_CAP -- and nothing for merely ending the fight close;
--   * the avatar has no bond with itself, and a forgotten (dismissed or fallen) hire's bond is gone.

local Bond = require("models.bond")
local Player = require("models.player")

local function unit(id, x, y, opts)
    opts = opts or {}
    return { char = { id = id }, side = opts.side or "party", x = x, y = y,
             alive = opts.alive ~= false, summoned = opts.summoned }
end

local function company()
    local p = Player.new()
    p.roster = {
        { id = "character_avatar" }, { id = "character_rowan" }, { id = "character_xin" },
        { id = "character_gyeom" }, { id = "character_hire@knight.dwarf.7" },
    }
    p.runsStarted = 3
    return p
end

return {
    {
        name = "Rowan and Xin start at D with no bonus, everyone else at nothing, the avatar at no bond at all",
        fn = function()
            local p = company()
            assert(Bond.rank(p, "character_rowan") == "D", "Rowan should start at D")
            assert(Bond.rank(p, "character_xin") == "D", "Xin should start at D")
            assert(Bond.points(p, "character_rowan") == 0, "a seeded D has no points")
            assert(Bond.HIT.D == nil, "D lends no Hit or Avoid")
            assert(Bond.rank(p, "character_gyeom") == nil, "Gyeom should start with no bond")
            assert(Bond.entry(p, "character_avatar") == nil, "the avatar has no bond with itself")
            assert(Bond.toNext(p, "character_rowan") == Bond.THRESHOLD.C)
        end,
    },
    {
        name = "an old save's unearned B seed is re-seeded to D, keeping points earned on top; an earned B stays",
        fn = function()
            local p = company()
            p.avatarBonds = {
                character_rowan = { points = Bond.THRESHOLD.B + 2, rank = "B" },          -- the old seed, +2
                character_xin = { points = Bond.THRESHOLD.B, rank = "B", rankRun = 4 },  -- risen in play
            }
            assert(Bond.rank(p, "character_rowan") == "D", "the seeded B should come back as D")
            assert(Bond.points(p, "character_rowan") == 2, "the earned points survive")
            assert(Bond.rank(p, "character_xin") == "B", "a B a run raised is the player's and stays")
        end,
    },
    {
        name = "a rank rises by points alone, one step a fight, in the same run, up to S",
        fn = function()
            local p = company()
            local from, to = Bond.award(p, "character_gyeom", Bond.THRESHOLD.C - 1, 5)
            assert(from == nil and to == nil, "short of C: no rank")
            from, to = Bond.award(p, "character_gyeom", 1, 5)
            assert(from == nil and to == "C", "reaching C's threshold rises to C")
            from, to = Bond.award(p, "character_gyeom", Bond.THRESHOLD.B - Bond.THRESHOLD.C, 5)
            assert(from == "C" and to == "B", "the same run can rise again")
            from, to = Bond.award(p, "character_gyeom", Bond.THRESHOLD.S, 5)
            assert(from == "B" and to == "A", "one step a call, however many points")
            from, to = Bond.award(p, "character_gyeom", 1, 5)
            assert(from == "A" and to == "S", "the banked points carry the next step")
            assert(Bond.award(p, "character_gyeom", 50, 5) == nil, "S is the top")
            assert(Bond.toNext(p, "character_gyeom") == nil)
        end,
    },
    {
        name = "the thresholds put S near floor 13 of one run at the measured deed rate",
        fn = function()
            -- Descent.FLOOR_FIGHTS a floor (4.1 measured), at 1.0 deeds a partner-fight (the run
            -- simulator's autobattle) to 1.5 (a pair kept together on purpose): S lands on floors 11-17
            -- across that band and on 13 at its centre, and every rank sits strictly above the last.
            local Descent = require("models.descent")
            local perFloor = 4.1
            assert(Descent.FLOOR_FIGHTS == 4, "the fight count the pacing was measured against moved")
            local function floorOf(points, rate) return points / (perFloor * rate) end
            local mid = floorOf(Bond.THRESHOLD.S, 1.25)
            assert(mid >= 12 and mid <= 14.5, "S should land near floor 13 at 1.25 deeds a fight: " .. mid)
            assert(floorOf(Bond.THRESHOLD.S, 1.5) >= 10, "a pair played on purpose should not reach S before floor 10")
            assert(floorOf(Bond.THRESHOLD.C, 1.25) >= 1.5, "C should not come in the first handful of fights")
            for i = 2, #Bond.RANKS do
                local lo, hi = Bond.RANKS[i - 1], Bond.RANKS[i]
                assert(Bond.THRESHOLD[hi] > Bond.THRESHOLD[lo], hi .. " should cost more than " .. lo)
                assert((Bond.HIT[hi] or 0) > (Bond.HIT[lo] or 0) or lo == "D", hi .. " should lend more than " .. lo)
            end
        end,
    },
    {
        name = "a won fight pays the deeds, capped, nothing for standing close, nothing to the avatar",
        fn = function()
            local p = company()
            local units = {
                unit("character_avatar", 1, 1),
                unit("character_rowan", 2, 2),                  -- close, but did nothing together
                unit("character_xin", 5, 5),
                unit("character_gyeom", 1, 2, { alive = false }), -- fell after its deed
                unit("character_hire@knight.dwarf.7", 1, 3, { summoned = true }),
                unit("character_bandit", 1, 2, { side = "enemy" }),
            }
            local before = Bond.points(p, "character_rowan")
            Bond.settle(p, units, { character_xin = 5, character_gyeom = 1 }, 3)
            assert(Bond.points(p, "character_rowan") == before, "standing close is not a deed")
            assert(Bond.points(p, "character_xin") == Bond.DEED_CAP, "Xin's deeds count, capped")
            assert(Bond.points(p, "character_gyeom") == 1, "a fallen partner still banks its deeds")
            assert(Bond.points(p, "character_hire@knight.dwarf.7") == 0, "a summoned body earns nothing")
            assert(Bond.entry(p, "character_avatar") == nil)
        end,
    },
    {
        name = "a fight with no deeds pays nobody",
        fn = function()
            local p = company()
            local before = Bond.points(p, "character_rowan")
            Bond.settle(p, { unit("character_avatar", 1, 1), unit("character_rowan", 1, 2) }, {}, 3)
            assert(Bond.points(p, "character_rowan") == before)
        end,
    },
    {
        name = "settle reports the rises it caused, for the bond card",
        fn = function()
            local p = company()
            p.avatarBonds = { character_gyeom = { points = Bond.THRESHOLD.C - 1 } }
            local rises = Bond.settle(p, { unit("character_avatar", 1, 1), unit("character_gyeom", 1, 2) }, { character_gyeom = 1 }, 3)
            assert(#rises == 1 and rises[1].id == "character_gyeom" and rises[1].to == "C" and rises[1].from == nil)
        end,
    },
    {
        name = "forgetting a pair drops it, and the list shows what is left, best first",
        fn = function()
            local p = company()
            Bond.award(p, "character_hire@knight.dwarf.7", 2, 3)
            local list = Bond.list(p)
            assert(#list == 3, "Rowan, Xin and the hire")
            assert(list[1].rank == "D" and list[3].id == "character_hire@knight.dwarf.7")
            Bond.forget(p, "character_hire@knight.dwarf.7")
            assert(#Bond.list(p) == 2)
            assert(Bond.points(p, "character_hire@knight.dwarf.7") == 0)
        end,
    },
    {
        name = "bonds survive a save under their own key, away from the retired hiring purse",
        fn = function()
            local Save = require("models.save")
            local p = Player.new()
            p.roster = { require("models.character").instantiate("character_avatar"),
                         require("models.character").instantiate("character_rowan"),
                         require("models.character").instantiate("character_gyeom") }
            Bond.award(p, "character_gyeom", Bond.THRESHOLD.C, 2)
            Bond.rank(p, "character_rowan") -- seeds Rowan's D
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
            assert(Bond.rank(back, "character_gyeom") == "C" and Bond.points(back, "character_gyeom") == Bond.THRESHOLD.C)
            assert(back.avatarBonds.character_gyeom.rankRun == 2, "the earned-rise stamp is kept")
            assert(Bond.rank(back, "character_rowan") == "D")
        end,
    },
    {
        name = "the bond card carries the rank's Hit/Avoid chips and a New row per verb it opens",
        fn = function()
            local LevelupCard = require("ui.levelup_card")
            local card = LevelupCard.showBond({ id = "character_avatar", name = "Ash" },
                { id = "character_rowan", name = "Rowan" }, "B", "A", { playSound = function() end })
            assert(card.kind == "bond" and card.fromRank == "B" and card.toRank == "A")
            assert(#card.rows == 4, "Hit, Avoid, Follow-up, Stand Firm")
            assert(card.rows[1].gain == Bond.HIT.A - Bond.HIT.B, "Hit grew by the step")
            assert(card.rows[3].isNew and card.rows[3].value == "Follow-up")
            assert(card.chipCount == 2, "the two figures that grew get chips")
            local first = LevelupCard.showBond(nil, { id = "x", name = "X" }, nil, "C", { playSound = function() end })
            assert(#first.rows == 2 and first.rows[1].gain == Bond.HIT.C, "a first rank opens no verb")
        end,
    },
}
