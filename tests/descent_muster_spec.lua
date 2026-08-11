-- Tests for models/descent_muster.lua -- the company a descent is fought with.
--
-- The muster is the first decision of a run and there is no second one like it: the bodies picked here
-- are the bodies that reach the bottom, and nothing in the mode recruits. So the cases below are mostly
-- about the muster never being able to hand a player something unplayable -- a shelf that cannot fill a
-- board, a purse that cannot afford one -- and about a body arriving as what its blueprint says it is.

local Muster = require("models.descent_muster")
local Character = require("models.character")
local Player = require("models.player")

return {
    { name = "the shelf is reproducible from its seed, and offers no body twice", fn = function()
        local a = Muster.shelf(4242)
        local b = Muster.shelf(4242)
        assert(#a == Muster.SHELF_SIZE, "a shelf is SHELF_SIZE bodies")
        for i, id in ipairs(a) do
            assert(b[i] == id, "the same seed must deal the same shelf on any machine")
        end
        assert(Muster.shelf(4243)[1] ~= a[1] or Muster.shelf(9999)[1] ~= a[1],
            "and a different seed must deal a different one")

        local seen = {}
        for _, id in ipairs(a) do
            assert(not seen[id], id .. " is on the shelf twice, so the shelf offers fewer bodies than it says")
            seen[id] = true
            assert(Character.defs[id], id .. " is not a real blueprint")
        end
    end },

    { name = "the shelf is a choice, not an inventory", fn = function()
        -- A shelf that fields exactly the company is not a shelf -- there would be nothing to decide.
        assert(Muster.SHELF_SIZE > Muster.COMPANY_MAX,
            "the shelf must offer more bodies than a company can take")
        assert(#Muster.pool() >= Muster.SHELF_SIZE,
            "and the pool must be able to fill it")
    end },

    { name = "a body is priced off its tier, so the purse is a real trade", fn = function()
        -- Flat pricing would make the budget decoration: it would meter out eight bodies and never once
        -- refuse anything. Tiered, the purse asks how many against how good.
        local plain = Muster.costOf("character_knight")
        assert(plain >= 1, "every body costs something")
        assert(Muster.cost({ "character_knight", "character_knight" }) == plain * 2, "and costs add up")
        assert(Muster.cost({}) == 0, "an empty company costs nothing")

        -- The trade actually exists in the content: the pool must hold bodies at more than one price, or
        -- the tiering is a formula over a constant.
        local prices = {}
        for _, id in ipairs(Muster.pool()) do prices[Muster.costOf(id)] = true end
        local distinct = 0
        for _ in pairs(prices) do distinct = distinct + 1 end
        assert(distinct >= 2, "the pool must offer bodies at more than one price")
    end },

    { name = "no shelf can leave a run unable to fill a board", fn = function()
        -- The one thing the budget must never do. COMPANY_MIN is the field itself: a player who cannot
        -- afford that many has been handed a run they cannot play, and no amount of clever picking fixes
        -- it. Checked against the DEAREST body in the pool, so it holds for the worst shelf that exists
        -- rather than for a typical one.
        local dearest = 0
        for _, id in ipairs(Muster.pool()) do
            dearest = math.max(dearest, Muster.costOf(id))
        end
        assert(dearest * Muster.COMPANY_MIN <= Muster.BUDGET,
            "the purse must afford " .. Muster.COMPANY_MIN .. " bodies at the dearest price in the pool")
        assert(Muster.COMPANY_MIN == Player.MAX_FIELD,
            "and the floor is the board: a company that cannot fill the field is not a company")
    end },

    { name = "the two refusals are different facts and say so", fn = function()
        -- A screen that says "no" without saying which is a screen the player has to experiment against:
        -- a full company is fixed for the rest of the muster, an empty purse clears the moment something
        -- dearer is put back.
        local cheap = nil
        for _, id in ipairs(Muster.pool()) do
            if Muster.costOf(id) == 1 then cheap = id; break end
        end
        assert(cheap, "the pool has a one-coin body to fill a company with")

        local full = {}
        for _ = 1, Muster.COMPANY_MAX do full[#full + 1] = cheap end
        assert(not Muster.canTake(full, cheap), "a full company takes nobody else")
        assert(Muster.refusal(full, cheap):find("full"), "and it says the company is full")

        -- A purse spent down below the price of the next body refuses for the other reason.
        local dear, dearId = 0, nil
        for _, id in ipairs(Muster.pool()) do
            if Muster.costOf(id) > dear then dear, dearId = Muster.costOf(id), id end
        end
        local broke = {}
        while Muster.remaining(broke) >= dear and #broke < Muster.COMPANY_MAX - 1 do
            broke[#broke + 1] = dearId
        end
        if Muster.remaining(broke) < dear then
            assert(not Muster.canTake(broke, dearId), "a spent purse buys nothing")
            assert(Muster.refusal(broke, dearId):find("purse"), "and it says so")
        end

        assert(Muster.refusal({}, cheap) == nil, "an empty company refuses nobody")
    end },

    { name = "a mustered body arrives as its blueprint, kit intact", fn = function()
        -- THE LINE BETWEEN THIS AND DRAFT'S STORE. Draft strips a bought unit to its chassis because
        -- there the gear row is the draft; a descent's gear comes off its floors, so a body arrives
        -- wearing exactly what data/characters/<id>.lua gives it and the caches are what change that.
        local company = Muster.company({ "character_knight", "character_mage" })
        assert(#company == 2, "every pick becomes a body")

        local knight = company[1]
        local def = Character.defs.character_knight
        assert(knight.id == "character_knight", "and it is the body that was picked")

        local carried = 0
        for _, item in pairs(knight.inventory or {}) do
            if item then carried = carried + 1 end
        end
        local authored = 0
        for _, id in ipairs(def.startingItems or {}) do
            if id then authored = authored + 1 end
        end
        assert(authored > 0, "the knight blueprint authors a kit to check against")
        assert(carried == authored, "a mustered body carries its whole authored kit, unstripped")
    end },

    { name = "a company is ready only once it can fill the board", fn = function()
        local picks = {}
        for i = 1, Muster.COMPANY_MIN do
            assert(not Muster.ready(picks), i - 1 .. " bodies cannot stand a full field")
            picks[#picks + 1] = "character_knight"
        end
        assert(Muster.ready(picks), Muster.COMPANY_MIN .. " bodies can")
    end },
}
