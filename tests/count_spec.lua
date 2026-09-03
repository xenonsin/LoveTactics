-- Tests for Iselle's tally -- models/descent.lua's count, the price on coming back up early.
--
-- WHAT IS ACTUALLY AT RISK HERE is not the arithmetic, which is three lines, but the SEAMS: that the
-- payback rides the one place a floor number rises, that the seal pays once, that a wipe never touches
-- it, and that an honest descent never sees the number move while a shuttle empties it in five floors.
-- Those are the claims the whole design rests on and they are all cheap to pin.
--
-- The climb-out itself lives in states/game.lua's ascent branch and cannot be driven headlessly, so what
-- is exercised here is Descent.climbOut -- which is what that branch calls and the only thing it does.
--
-- THE TALLY IS THE COMPANY'S, NOT THE RUN'S, and that is why every case below holds a player. It lived
-- on the run while a descent outlived every climb-out; it cannot, once a descent is a thing you finish
-- and throw away. See Descent.count, and the run-ends case at the bottom, which is the one that would
-- have caught the move being needed.

local Descent = require("models.descent")
local Save = require("models.save")
local Player = require("models.player")
local Building = require("models.building")
local CountMeter = require("ui.count_meter") -- for rowWidth only; .new() would want love.graphics

return {
    { name = "a fresh company has left nothing behind it", fn = function()
        local p = Player.new()
        assert(Descent.count(p) == 0, "a company that has never turned back owes nothing")
        assert(Descent.countBand(p).id == "low", "and stands in the lowest band")
        assert(Descent.count(nil) == 0, "and nil is readable, since the readout asks before a save exists")
    end },

    { name = "coming back up raises it, going deeper pays it back", fn = function()
        local p = Player.new()
        local run = Descent.new(p, 1234)
        Descent.climbOut(p)
        assert(Descent.count(p) == 1, "the way up costs one")
        Descent.climbOut(p)
        assert(Descent.count(p) == 2, "and one each time")
        Descent.advance(run, p)
        assert(Descent.count(p) == 1, "reaching a floor prunes one back")
    end },

    { name = "it never goes below nought", fn = function()
        local p = Player.new()
        local run = Descent.new(p, 1234)
        for _ = 1, 5 do Descent.advance(run, p) end
        assert(Descent.count(p) == 0,
            "descending with a clean tally banks no credit -- it is the state of the rift, not a purse")
    end },

    { name = "it never goes above the maximum", fn = function()
        local p = Player.new()
        for _ = 1, Descent.COUNT_MAX + 10 do Descent.climbOut(p) end
        assert(Descent.count(p) == Descent.COUNT_MAX, "the tally stops at its own maximum")
        assert(Descent.countBand(p).id == "up", "and the top of it is the band that ends things")
    end },

    { name = "a felled general takes it down, once", fn = function()
        local p = Player.new()
        local run = Descent.new(p, 1234)
        for _ = 1, 10 do Descent.climbOut(p) end
        -- Stand on the first general's floor and beat her.
        run.floor = Descent.FLOORS_PER_CIRCLE
        assert(Descent.isGeneralFloor(run.floor), "the stratum's last floor is hers")
        Descent.clearFloor(run, p)
        assert(Descent.count(p) == 10 - Descent.COUNT_SEAL, "a seal pays back COUNT_SEAL")
        Descent.clearFloor(run, p)
        assert(Descent.count(p) == 10 - Descent.COUNT_SEAL,
            "and crediting the same floor twice must not pay twice")
    end },

    { name = "clearing a floor with nobody on its stair pays nothing", fn = function()
        local p = Player.new()
        local run = Descent.new(p, 1234)
        for _ = 1, 5 do Descent.climbOut(p) end
        -- A floor inside a circle rather than the last of one. Written off FLOORS_PER_CIRCLE rather
        -- than as a literal 1, because the stack's shape is one constant away from every circle owning
        -- a single floor -- at which point floor one IS a general's and a hard-coded case here would be
        -- asserting something the mode no longer does.
        local ordinary
        for floor = 1, Descent.CIRCLE_FLOORS do
            if not Descent.isGeneralFloor(floor) then ordinary = floor break end
        end
        if not ordinary then return end -- every circle floor holds a general; nothing to assert
        run.floor = ordinary
        Descent.clearFloor(run, p)
        assert(Descent.count(p) == 5, "only a general is worth anything to the tally")
    end },

    { name = "an honest descent never leaves the lowest band", fn = function()
        local p = Player.new()
        local run = Descent.new(p, 4321)
        local peak = 0
        for _ = 1, Descent.FLOORS - 1 do
            -- Measured at the WORST moment of each floor, which is standing in town having just come
            -- up -- not after the stair has already paid it back. A peak read post-descent would
            -- flatter every play style equally and prove nothing.
            Descent.climbOut(p) -- once a floor: the pacing move the ascent tile was built for
            peak = math.max(peak, Descent.count(p))
            Descent.clearFloor(run, p)
            Descent.advance(run, p)
        end
        assert(peak < Descent.COUNT_BANDS[#Descent.COUNT_BANDS - 1].at,
            "withdrawing once a floor and pressing on never even changes the city, got " .. peak)
    end },

    { name = "a shuttle fills it inside five floors", fn = function()
        local p = Player.new()
        local run = Descent.new(p, 4321)
        local filledOn
        for floor = 1, Descent.FLOORS - 1 do
            for _ = 1, 7 do Descent.climbOut(p) end -- up after every fight; a floor seats seven or eight
            if not filledOn and Descent.count(p) >= Descent.COUNT_MAX then filledOn = floor end
            Descent.clearFloor(run, p)
            Descent.advance(run, p)
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
            local p = Player.new()
            p.count = n
            reached[Descent.countBand(p).id] = true
        end
        for _, band in ipairs(Descent.COUNT_BANDS) do
            assert(reached[band.id], "every band is reachable inside the range: " .. band.id)
        end
        local p = Player.new()
        for n = 0, Descent.COUNT_MAX do
            p.count = n
            assert(Descent.countBand(p), "every count from nought to the maximum lands in a band: " .. n)
        end
    end },

    { name = "the tally survives the real serializer", fn = function()
        local p = Player.new()
        for _ = 1, 6 do Descent.climbOut(p) end
        local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
        assert(Descent.count(back) == 6, "a load is not an extraction and must lose nothing")
        -- ...and a save from a company that never turned back reads as nought. Built from a real
        -- snapshot rather than a bare table: Save.restore refuses anything whose `version` does not
        -- match, so a hand-rolled fixture comes back nil and asserts nothing at all.
        local fresh = Save.restore(Save.snapshot(Player.new()))
        assert(Descent.count(fresh) == 0, "no tally on the save reads as a quiet rift")
    end },

    { name = "a tally saved on the old run is carried forward, not dropped", fn = function()
        -- THE MIGRATION, pinned. Every save written before the move put the number on the run
        -- (models/descent.lua's snapshot no longer does), so Save.restore reads it off the RAW snapshot
        -- as a fallback. Without this a company mid-descent when the move landed would walk into the
        -- city at nought and the readout would quietly lie about what they had done.
        --
        -- The old shape is built by TAKING A REAL SNAPSHOT APART rather than by writing one out, so the
        -- fixture carries the version Save.restore insists on and cannot drift from the real format.
        local snap = Save.snapshot(Player.new())
        snap.count = nil
        snap.descentRun = { floor = 3, seed = 1, count = 7 }
        local back = Save.restore(snap)
        assert(back, "the fixture is a real save and must load")
        assert(Descent.count(back) == 7, "an old save's tally comes forward onto the company")
        -- ...and the player's own field wins where both are present, since it is the one being written.
        snap.count = 2
        local both = Save.restore(snap)
        assert(Descent.count(both) == 2, "the company's own tally is the authority once it has one")
    end },

    { name = "the tally outlives the run that earned it", fn = function()
        -- THE CASE THE MOVE EXISTS FOR. A descent ends -- and under an extraction descent it ends every
        -- time anybody walks out -- while the state of the rift does not. On the run, this read nought
        -- the moment the expedition was dropped, which is exactly when the player is standing in the
        -- city looking at what they left behind.
        local p = Player.new()
        local run = Descent.new(p, 99)
        p.descentRun = run
        for _ = 1, 4 do Descent.climbOut(p) end
        assert(Descent.count(p) == 4, "four withdrawals, four marks")
        p.descentRun = nil -- the run is over, however it ended
        assert(Descent.count(p) == 4,
            "and the rift is still four floors unpruned with nobody down there")
        assert(Descent.countBand(p).id ~= nil, "so the plaza still has a band to draw")
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
        Descent.advance(run, p)
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

    { name = "a new lap opens on a rift nobody has left unpruned", fn = function()
        -- Breaking the Crown is the one event that can honestly put the number back, and a second
        -- campaign opening on a breach warning earned by a company that has since won would be the
        -- first campaign's bookkeeping leaking into a fresh start (Player.newGamePlus).
        local p = Player.new()
        for _ = 1, 9 do Descent.climbOut(p) end
        Descent.markClimbedOut(p)
        Descent.markTallyTaught(p)
        Player.newGamePlus(p)
        assert(Descent.count(p) == 0, "a new lap begins on a quiet rift")
        assert(Descent.everClimbedOut(p) and Descent.tallyTaught(p),
            "but the marks are things this player did and was told, and carry")
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
        Descent.clearFloor(run, p)
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
