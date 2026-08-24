-- Tests for Iselle's tally -- models/descent.lua's count, the price on coming back up early.
--
-- WHAT IS ACTUALLY AT RISK HERE is not the arithmetic, which is three lines, but the SEAMS: that the
-- payback rides the one place a floor number rises, that the seal pays once, that a wipe never touches
-- it, and that an honest descent never sees the number move while a shuttle empties it in five floors.
-- Those are the claims the whole design rests on and they are all cheap to pin.
--
-- The climb-out itself lives in states/game.lua's ascent branch and cannot be driven headlessly, so what
-- is exercised here is Descent.climbOut -- which is what that branch calls and the only thing it does.

local Descent = require("models.descent")
local Save = require("models.save")
local Player = require("models.player")
local Building = require("models.building")
local CountMeter = require("ui.count_meter") -- for rowWidth only; .new() would want love.graphics

return {
    { name = "a fresh run has left nothing behind it", fn = function()
        local run = Descent.new(Player.new(), 1234)
        assert(Descent.count(run) == 0, "a company that has never turned back owes nothing")
        assert(Descent.countBand(run).id == "low", "and stands in the lowest band")
        assert(Descent.count(nil) == 0, "and nil is readable, since the readout asks before a run exists")
    end },

    { name = "coming back up raises it, going deeper pays it back", fn = function()
        local run = Descent.new(Player.new(), 1234)
        Descent.climbOut(run)
        assert(Descent.count(run) == 1, "the way up costs one")
        Descent.climbOut(run)
        assert(Descent.count(run) == 2, "and one each time")
        Descent.advance(run)
        assert(Descent.count(run) == 1, "reaching a floor prunes one back")
    end },

    { name = "it never goes below nought", fn = function()
        local run = Descent.new(Player.new(), 1234)
        for _ = 1, 5 do Descent.advance(run) end
        assert(Descent.count(run) == 0,
            "descending with a clean tally banks no credit -- it is the state of the rift, not a purse")
    end },

    { name = "it never goes above the maximum", fn = function()
        local run = Descent.new(Player.new(), 1234)
        for _ = 1, Descent.COUNT_MAX + 10 do Descent.climbOut(run) end
        assert(Descent.count(run) == Descent.COUNT_MAX, "the tally stops at its own maximum")
        assert(Descent.countBand(run).id == "up", "and the top of it is the band that ends things")
    end },

    { name = "a felled general takes it down, once", fn = function()
        local run = Descent.new(Player.new(), 1234)
        for _ = 1, 10 do Descent.climbOut(run) end
        -- Stand on the first general's floor and beat her.
        run.floor = Descent.FLOORS_PER_CIRCLE
        assert(Descent.isGeneralFloor(run.floor), "the stratum's last floor is hers")
        Descent.clearFloor(run)
        assert(Descent.count(run) == 10 - Descent.COUNT_SEAL, "a seal pays back COUNT_SEAL")
        Descent.clearFloor(run)
        assert(Descent.count(run) == 10 - Descent.COUNT_SEAL,
            "and crediting the same floor twice must not pay twice")
    end },

    { name = "clearing an ordinary floor pays nothing", fn = function()
        local run = Descent.new(Player.new(), 1234)
        for _ = 1, 5 do Descent.climbOut(run) end
        run.floor = 1
        assert(not Descent.isGeneralFloor(1), "floor one holds nobody")
        Descent.clearFloor(run)
        assert(Descent.count(run) == 5, "only a general is worth anything to the tally")
    end },

    { name = "an honest descent never leaves the lowest band", fn = function()
        local run = Descent.new(Player.new(), 4321)
        local peak = 0
        for _ = 1, Descent.FLOORS - 1 do
            -- Measured at the WORST moment of each floor, which is standing in town having just come
            -- up -- not after the stair has already paid it back. A peak read post-descent would
            -- flatter every play style equally and prove nothing.
            Descent.climbOut(run) -- once a floor: the pacing move the ascent tile was built for
            peak = math.max(peak, Descent.count(run))
            Descent.clearFloor(run)
            Descent.advance(run)
        end
        assert(peak < Descent.COUNT_BANDS[#Descent.COUNT_BANDS - 1].at,
            "withdrawing once a floor and pressing on never even changes the city, got " .. peak)
    end },

    { name = "a shuttle fills it inside five floors", fn = function()
        local run = Descent.new(Player.new(), 4321)
        local filledOn
        for floor = 1, Descent.FLOORS - 1 do
            for _ = 1, 7 do Descent.climbOut(run) end -- up after every fight; a floor seats seven or eight
            if not filledOn and Descent.count(run) >= Descent.COUNT_MAX then filledOn = floor end
            Descent.clearFloor(run)
            Descent.advance(run)
        end
        assert(filledOn and filledOn <= 5,
            "climbing out after every fight should fill the tally by floor five, got " .. tostring(filledOn))
    end },

    { name = "the bands are ordered, and only the top of them speaks", fn = function()
        local seen = {}
        local last, warned = nil, 0
        for _, band in ipairs(Descent.COUNT_BANDS) do
            assert(type(band.id) == "string" and not seen[band.id], "band ids are unique: " .. tostring(band.id))
            seen[band.id] = true
            -- A band either says nothing or says something real. An empty string is neither, and would
            -- draw as a blank line holding space above the marks.
            if band.phrase ~= nil then
                assert(type(band.phrase) == "string" and #band.phrase > 0,
                    band.id .. " either carries a warning or carries none")
                warned = warned + 1
            end
            assert(last == nil or band.at < last, "bands are listed deepest-first so a lookup can stop")
            last = band.at
        end
        -- THE WARNING IS THE ONLY TEXT AND IT BELONGS AT THE TOP. Marks alone are the readout; a line of
        -- prose on every band is the same fact twice and leaves the card no way to raise its voice.
        assert(warned > 0 and warned < #Descent.COUNT_BANDS,
            "some bands warn and some do not, or the warning stops being a signal")
        assert(Descent.COUNT_BANDS[1].phrase, "the highest band is one of the ones that warns")
        assert(Descent.COUNT_BANDS[#Descent.COUNT_BANDS].phrase == nil,
            "and the lowest is silent -- a fresh tally says nothing at all")
        assert(last == 0, "the lowest band starts at nought, so no count is ever bandless")
        -- MOVING THE CEILING MUST MOVE THE BANDS. Dropping COUNT_MAX without re-spacing these leaves the
        -- top band unreachable and the one below it covering the whole meter, which is invisible in play
        -- and obvious here.
        assert(Descent.COUNT_BANDS[1].at == Descent.COUNT_MAX,
            "the top band begins exactly at the maximum: band " .. Descent.COUNT_BANDS[1].at ..
            " against a maximum of " .. Descent.COUNT_MAX)
        local reached = {}
        for n = 0, Descent.COUNT_MAX do
            local run = Descent.new(Player.new(), 1)
            run.count = n
            reached[Descent.countBand(run).id] = true
        end
        for _, band in ipairs(Descent.COUNT_BANDS) do
            assert(reached[band.id], "every band is reachable inside the range: " .. band.id)
        end
        local run = Descent.new(Player.new(), 1)
        for n = 0, Descent.COUNT_MAX do
            run.count = n
            assert(Descent.countBand(run), "every count from nought to the maximum lands in a band: " .. n)
        end
    end },

    { name = "the tally survives the real serializer", fn = function()
        local run = Descent.new(Player.new(), 777)
        for _ = 1, 6 do Descent.climbOut(run) end
        local back = Descent.restore(Save.decode("return " .. Save.encode(Descent.snapshot(run), 0)))
        assert(Descent.count(back) == 6, "a resume is not an extraction and must lose nothing")
        -- ...and a save written before the tally existed reads as a company that never turned back.
        local older = Descent.restore({ floor = 3, seed = 1 })
        assert(Descent.count(older) == 0, "an older save has no tally, which reads as nought")
    end },

    { name = "the two marks are one-way and independent", fn = function()
        local p = Player.new()
        assert(not Descent.everClimbedOut(p), "a fresh company has never turned back")
        assert(not Descent.tallyTaught(p), "and nobody has explained the tally to it")
        Descent.markClimbedOut(p)
        assert(Descent.everClimbedOut(p), "the readout opens the instant the stair is taken")
        assert(not Descent.tallyTaught(p),
            "but the scene has not played yet -- that is why these are two marks and not one")
        Descent.markTallyTaught(p)
        assert(Descent.tallyTaught(p), "and it closes when her scene finishes")
        -- One-way: the count falling back to nought must not un-teach anything.
        local run = Descent.new(p, 1)
        Descent.advance(run)
        assert(Descent.everClimbedOut(p) and Descent.tallyTaught(p),
            "descending again does not take the readout back off the plaza")
    end },

    { name = "the marks ride the save", fn = function()
        local p = Player.new()
        Descent.markClimbedOut(p)
        Descent.markTallyTaught(p)
        local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
        assert(Descent.everClimbedOut(back), "the readout stays open across a load")
        assert(Descent.tallyTaught(back), "and she does not explain it twice")
    end },

    { name = "a circle sealed underground takes its general out of the finale", fn = function()
        local Calendar = require("models.calendar")
        local p = Player.new()
        local all = Calendar.generalsStanding(p)
        assert(all == #Descent.SINS,
            "a company that has felled nobody faces all seven")
        -- Seal one circle the way a descent does: stand on her floor and beat her.
        local run = Descent.new(p, 1234)
        p.descentRun = run
        run.floor = Descent.FLOORS_PER_CIRCLE
        Descent.clearFloor(run)
        assert(Calendar.generalsStanding(p) == all - 1,
            "felling a general on her own floor must count, even though no quest was completed")
    end },

    { name = "every band has a colour, and the ladder is four distinct steps", fn = function()
        -- REPORTED IS NOT ENFORCED: a band added without an entry here draws with a nil colour, which
        -- is either an error or the last colour set, depending on where in the frame it lands.
        local seenHex = {}
        for _, band in ipairs(Descent.COUNT_BANDS) do
            local c = CountMeter.BAND_COLOR[band.id]
            assert(type(c) == "table" and #c >= 3, band.id .. " has no colour on the ladder")
            local hex = table.concat({ c[1], c[2], c[3] }, ",")
            assert(not seenHex[hex], "two bands share a colour, so the ladder has a step nobody can see")
            seenHex[hex] = true
        end
        -- The mark ladder is per POSITION, so mark 1 is the safe end and the last mark is the worst.
        assert(CountMeter.BAND_COLOR[Descent.bandAt(1).id] ==
               CountMeter.BAND_COLOR[Descent.COUNT_BANDS[#Descent.COUNT_BANDS].id],
            "the first mark wears the lowest band's colour")
        assert(CountMeter.BAND_COLOR[Descent.bandAt(Descent.COUNT_MAX).id] ==
               CountMeter.BAND_COLOR[Descent.COUNT_BANDS[1].id],
            "and the last mark wears the highest band's")
    end },

    { name = "the row of marks fits the plate it is drawn on", fn = function()
        -- REPORTED IS NOT ENFORCED: the widget derives its width from Descent.COUNT_MAX, so raising the
        -- maximum silently overflows the Rift's card unless something asks. This asks.
        local card = Building.GRID.city.gate
        local row = CountMeter.rowWidth(Descent.COUNT_MAX)
        assert(row <= card.w - 24,
            "the tally must sit inside the Rift's plate with room to breathe: row " .. row ..
            " against a card of " .. card.w)
    end },
}
