-- BONDS (models/bond.lua, approved 2026-10-25). Holds the promises the review rounds made:
--
--   * Rowan and Xin start at B; every other body, companions included, starts at nothing;
--   * the ranks are C / B / A at 3 / 8 / 16 points, and a rank rises AT MOST ONCE A RUN;
--   * a won fight pays a point to a partner that ended it standing within RANGE of a standing avatar,
--     plus its covering deeds, capped at DEED_CAP;
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
        name = "Rowan and Xin start at B, everyone else at nothing, the avatar at no bond at all",
        fn = function()
            local p = company()
            assert(Bond.rank(p, "character_rowan") == "B", "Rowan should start at B")
            assert(Bond.rank(p, "character_xin") == "B", "Xin should start at B")
            assert(Bond.points(p, "character_rowan") == Bond.THRESHOLD.B, "a seeded B sits on B's threshold")
            assert(Bond.rank(p, "character_gyeom") == nil, "Gyeom should start with no bond")
            assert(Bond.entry(p, "character_avatar") == nil, "the avatar has no bond with itself")
            assert(Bond.toNext(p, "character_rowan") == Bond.THRESHOLD.A - Bond.THRESHOLD.B)
        end,
    },
    {
        name = "a rank rises once a run, and the next run lets the banked points through",
        fn = function()
            local p = company()
            local from, to = Bond.award(p, "character_gyeom", 20, 5)
            assert(from == nil and to == "C", "twenty points in one run should buy C and only C")
            assert(Bond.points(p, "character_gyeom") == 20, "the points are banked in full")
            assert(Bond.award(p, "character_gyeom", 1, 5) == nil, "no second rise in the same run")
            assert(Bond.rank(p, "character_gyeom") == "C")
            from, to = Bond.award(p, "character_gyeom", 1, 6)
            assert(from == "C" and to == "B", "the next run should rise one rank")
            from, to = Bond.award(p, "character_gyeom", 1, 7)
            assert(from == "B" and to == "A", "and the run after, to A")
            assert(Bond.award(p, "character_gyeom", 50, 8) == nil, "A is the top")
        end,
    },
    {
        name = "a won fight pays the fight's point inside the range, deeds capped, nothing to the avatar",
        fn = function()
            local p = company()
            local units = {
                unit("character_avatar", 1, 1),
                unit("character_rowan", 2, 2),                  -- gap 2: in range
                unit("character_xin", 5, 5),                    -- far: no fight point
                unit("character_gyeom", 1, 2, { alive = false }), -- fell: no fight point
                unit("character_hire@knight.dwarf.7", 1, 3, { summoned = true }),
                unit("character_bandit", 1, 2, { side = "enemy" }),
            }
            local before = Bond.points(p, "character_rowan")
            Bond.settle(p, units, { character_xin = 5, character_gyeom = 1 }, 3)
            assert(Bond.points(p, "character_rowan") == before + 1, "Rowan ended within range")
            assert(Bond.points(p, "character_xin") == Bond.THRESHOLD.B + Bond.DEED_CAP,
                "Xin's deeds count without the fight point, capped")
            assert(Bond.points(p, "character_gyeom") == 1, "a fallen partner still banks its deeds")
            assert(Bond.points(p, "character_hire@knight.dwarf.7") == 0, "a summoned body earns nothing")
            assert(Bond.entry(p, "character_avatar") == nil)
        end,
    },
    {
        name = "a fallen avatar pays no fight point to anyone",
        fn = function()
            local p = company()
            local before = Bond.points(p, "character_rowan")
            Bond.settle(p, { unit("character_avatar", 1, 1, { alive = false }), unit("character_rowan", 1, 2) }, {}, 3)
            assert(Bond.points(p, "character_rowan") == before)
        end,
    },
    {
        name = "settle reports the rises it caused, for the bond card",
        fn = function()
            local p = company()
            p.avatarBonds = { character_gyeom = { points = 2 } }
            local rises = Bond.settle(p, { unit("character_avatar", 1, 1), unit("character_gyeom", 1, 2) }, {}, 3)
            assert(#rises == 1 and rises[1].id == "character_gyeom" and rises[1].to == "C" and rises[1].from == nil)
        end,
    },
    {
        name = "forgetting a pair drops it, and the list shows what is left, best first",
        fn = function()
            local p = company()
            Bond.award(p, "character_hire@knight.dwarf.7", 3, 3)
            local list = Bond.list(p)
            assert(#list == 3, "Rowan, Xin and the hire")
            assert(list[1].rank == "B" and list[3].id == "character_hire@knight.dwarf.7")
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
            Bond.award(p, "character_gyeom", 4, 2)
            Bond.rank(p, "character_rowan") -- seeds Rowan's B
            local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
            assert(Bond.rank(back, "character_gyeom") == "C" and Bond.points(back, "character_gyeom") == 4)
            assert(back.avatarBonds.character_gyeom.rankRun == 2, "the once-a-run stamp is kept")
            assert(Bond.rank(back, "character_rowan") == "B")
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
