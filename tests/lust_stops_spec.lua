-- LUST'S OWN STOPS (reviewed 2026-09-29, after Gluttony's): the Still Pool, the Mooring Post and the Ferry.
-- Each takes a piece of the company's say -- what it wants, whether it leaves, where it stands -- and each is
-- a question at a stop rather than a fight. The Favour (a charm traded both ways) was pitched and cut.
--
-- The seam they share with Gluttony's (Descent.queueOpening) is held in tests/gluttony_stops_spec.lua; what
-- is held here is Lust's half, and the one thing the queue learned for it: a status queued WITHOUT a count
-- keeps its authored magnitude, because Burn's magnitude is its damage.

local Crossroads = require("models.crossroads")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Player = require("models.player")

local function sinNamed(id)
    for _, sin in ipairs(Descent.SINS) do if sin.id == id then return sin end end
end

local function recorder()
    local log = { sealed = 0, restored = 0, ferried = 0, queued = {}, notes = {} }
    return log, {
        rnd = function() return 0 end,
        notify = function(m) log.notes[#log.notes + 1] = m end,
        grantSealed = function() log.sealed = log.sealed + 1; return true end,
        restore = function() log.restored = log.restored + 1 end,
        ferry = function() log.ferried = log.ferried + 1; return true end,
        queueOpening = function(side, id, n) log.queued[#log.queued + 1] = { side = side, id = id, n = n } end,
    }
end

local function option(stop, label)
    for _, o in ipairs(Crossroads.STOPS[stop].options) do if o.label == label then return o end end
    error(stop .. " has no option " .. label)
end

return {
    { name = "Lust's three stops have blueprints, never roll, and each has a gloss", fn = function()
        for _, kind in ipairs({ "still_pool", "mooring_post", "ferry" }) do
            local found
            for _, def in pairs(Encounter.defs) do if def.kind == kind then found = def end end
            assert(found, kind .. " has no blueprint")
            assert((found.weight or 0) == 0, kind .. " would roll onto a board at random")
            assert(Encounter.GLOSS[kind], kind .. " has no gloss sentence")
        end
        -- Renamed from the pitch on purpose: "The Still Water" is Lust's elite.
        assert(Encounter.get("encounter_the_still_water").name ~= Encounter.get("encounter_the_still_pool").name,
            "the stop and the elite do not share a name")
    end },

    { name = "every one of Lust's floors seats all three, once", fn = function()
        local sin = sinNamed("lust")
        local run = Descent.new(Player.new(), 1)
        local seen = 0
        for floor = 1, Descent.FLOORS do
            run.floor = floor
            local at = Descent.sinAt(run, floor)
            if at and at.id == "lust" then
                seen = seen + 1
                local kinds, g = Descent.circleStops(sin, floor)
                assert(table.concat(kinds, ",") == "still_pool,mooring_post,ferry",
                    "floor " .. floor .. ": " .. table.concat(kinds, ","))
                for _, k in ipairs(kinds) do assert(g[k].count == 1, k .. " is seated once") end
            end
        end
        assert(seen == 2, "Lust has two floors, found " .. seen)
    end },

    { name = "the Still Pool: reach in for a find and open the next fight Burning", fn = function()
        local log, ctx = recorder()
        option("still_pool", "Reach in").resolve(ctx)
        assert(log.sealed == 1, "reaching in hands up a sealed find")
        assert(log.queued[1] and log.queued[1].side == "party" and log.queued[1].id == "status_burn"
            and log.queued[1].n == nil, "and the company opens its next fight Burning, at Burn's own damage")
        log, ctx = recorder()
        option("still_pool", "Look away").resolve(ctx)
        assert(log.sealed == 0 and #log.queued == 0, "looking away does nothing")
    end },

    { name = "the Mooring Post: tie in to restore everything and open the next fight Rooted", fn = function()
        local log, ctx = recorder()
        option("mooring_post", "Tie in for the night").resolve(ctx)
        assert(log.restored == 1, "tying in restores every pool")
        assert(log.queued[1] and log.queued[1].side == "party" and log.queued[1].id == "status_root",
            "and the company opens its next fight Rooted")
        log, ctx = recorder()
        option("mooring_post", "Walk on").resolve(ctx)
        assert(log.restored == 0 and #log.queued == 0, "walking on does nothing")
    end },

    { name = "the Ferry: ride it and be carried; leave it and stay", fn = function()
        local log, ctx = recorder()
        option("ferry", "Ride it").resolve(ctx)
        assert(log.ferried == 1, "riding it carries the company")
        log, ctx = recorder()
        option("ferry", "Leave it").resolve(ctx)
        assert(log.ferried == 0, "leaving it does not")
    end },

    { name = "a status queued without a count keeps its authored magnitude", fn = function()
        local run = Descent.new(Player.new(), 1)
        run.floor = 3
        Descent.queueOpening(run, "party", "status_burn")
        Descent.queueOpening(run, "party", "status_burn")
        local back = Descent.restore(Descent.snapshot(run))
        local rows = Descent.takeOpening(back)
        assert(#rows == 1, "asked twice, laid once")
        assert(rows[1].opts.magnitude == nil, "no magnitude, so Burn burns at its own authored damage")
    end },
}
