-- Tests for THE RIFT CLOSING BEHIND THE COMPANY: the extraction rule, and the one thing that must
-- survive it.
--
-- THE RULE. Leaving banks everything and throws the DUNGEON away -- new stack, new shuffle, new boards,
-- from floor one. It is what makes the way up a decision: the stair used to stay open onto ground the
-- company had already cleared, so walking out cost a mark on the tally and nothing else.
--
-- BOTH EXITS RESET, and the symmetry is the load-bearing half. If dying preserved the floor stack and
-- leaving did not, a company standing deep with a thin haul would be better off letting itself be
-- killed -- the mode would have built an incentive to throw fights. That claim lives in the source scan
-- at the bottom, because neither exit can be driven headlessly.
--
-- AND THE PILE SURVIVES. A wipe drops what the run found as a guarded heap, and Descent.dropPack's own
-- header is explicit that it is "not income, it is the entire economy" -- deleting one turns an
-- expensive mistake into a permanent one. A reset that dropped a pack into a run it then discarded
-- would do exactly that, silently, and the player would find out by diving for something that was never
-- seeded. So the piles come out with the company and wait at their depth.

local Descent = require("models.descent")
local Player = require("models.player")
local Save = require("models.save")

local function runWithPile(floor, id)
    local run = Descent.new(nil, 4242)
    run.floor = floor
    run.drops = { { id = id or "drop1", floor = floor, x = 3, y = 4, count = 2,
                    items = { { id = "weapon_iron_sword", level = 0, quantity = 1 } },
                    guard = "drawn", guardIds = { "character_gorge_fly" } } }
    return run
end

local function source(path)
    local f = assert(io.open(path, "r"), "cannot read " .. path)
    local text = f:read("*a")
    f:close()
    return text
end

return {
    { name = "a closing rift carries its piles out onto the company", fn = function()
        local p, run = Player.new(), runWithPile(5)
        assert(#Descent.lostAt(p, 5) == 0, "a fresh company has left nothing anywhere")
        assert(Descent.strandPacks(p, run) == 1, "the one pile comes out")
        assert(#run.drops == 0, "and is off the run, which is about to be discarded")
        local waiting = Descent.lostAt(p, 5)
        assert(#waiting == 1, "it is waiting at the depth it was lost on")
        assert(waiting[1].guard == "drawn" and #waiting[1].guardIds == 1,
            "with the company that was standing over it -- re-drawing that would change the fight")
        assert(#Descent.lostAt(p, 4) == 0, "and only at that depth")
    end },

    { name = "stranding is idempotent, so a pile is never carried out twice", fn = function()
        local p, run = Player.new(), runWithPile(3)
        Descent.strandPacks(p, run)
        assert(Descent.strandPacks(p, run) == 0, "a second call finds nothing left to move")
        assert(#Descent.lostAt(p, 3) == 1, "and the company is owed one pile, not two")
    end },

    { name = "a stranded pile is picked up once and stops being owed", fn = function()
        local p, run = Player.new(), runWithPile(6, "drop7")
        Descent.strandPacks(p, run)
        local fresh = Descent.new(p, 99) -- a different expedition entirely
        local items = Descent.takePack(fresh, { id = "drop7" }, p)
        assert(items and #items == 1, "the new run can pick up what the old one left")
        assert(#Descent.lostAt(p, 6) == 0, "and it stops being owed")
        assert(Descent.takePack(fresh, { id = "drop7" }, p) == nil,
            "so it cannot be walked onto twice for two copies of everything")
    end },

    { name = "this run's piles and the company's stranded ones are both seated", fn = function()
        -- They are indistinguishable once down -- same marker, same guard, same walk back -- and a pile
        -- lost two rifts ago has to be as recoverable as one lost this hour.
        local Overworld = require("models.overworld")
        local p = Player.new()
        Descent.strandPacks(p, runWithPile(2, "old"))

        local run = Descent.new(p, 7)
        run.floor = 2
        run.drops = { { id = "new", floor = 2, x = 2, y = 2, count = 1,
                        items = { { id = "weapon_iron_sword", level = 0, quantity = 1 } },
                        guard = "drawn", guardIds = { "character_gorge_fly" } } }
        local grid = Overworld.generate({ cols = 10, rows = 10, seed = 5, stops = { min = 4, max = 6 } })
        local seated = Descent.markPacks(run, grid, 2, p)
        assert(seated == 2, "both piles are on the board, got " .. seated)
    end },

    { name = "the stranded ledger rides the save", fn = function()
        local p = Player.new()
        Descent.strandPacks(p, runWithPile(9, "deep"))
        local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(p), 0)))
        local waiting = Descent.lostAt(back, 9)
        assert(#waiting == 1, "the pile is still owed after a load")
        assert(waiting[1].id == "deep" and waiting[1].guard == "drawn",
            "with its id and its guard, which is what the marker and the fight are rebuilt from")
        -- ...and a company that has never lost anything carries no ledger at all.
        local clean = Save.restore(Save.snapshot(Player.new()))
        assert(#Descent.lostAt(clean, 1) == 0, "an unlucky-free company is owed nothing")
    end },

    { name = "both exits close the rift, and that symmetry is not an accident", fn = function()
        -- SOURCE-SCANNED, because neither exit can be driven headlessly and the defect this guards
        -- against is an ASYMMETRY: one exit keeping the floor stack while the other throws it away is an
        -- incentive to throw fights, and it would read as perfectly reasonable code on either side.
        local src = source("states/game.lua")

        local up = src:find("Descent.markClimbedOut(", 1, true)
        assert(up, "nothing takes the ascent stair any more -- retarget this case")
        local upTail = src:sub(up, up + 3000)
        assert(upTail:find("Descent.strandPacks(", 1, true),
            "climbing out closes the rift without carrying its piles out")
        assert(upTail:find("descentRun = nil", 1, true),
            "climbing out leaves the expedition open, so the next dive resumes a rift already left")

        local down = src:find("wiped = floor", 1, true)
        assert(down, "nothing sends a wiped company to the Gate any more -- retarget this case")
        local downHead = src:sub(math.max(1, down - 4000), down)
        assert(downHead:find("Descent.strandPacks(", 1, true),
            "a wipe closes the rift without carrying its piles out")
        assert(downHead:find("descentRun = nil", 1, true),
            "a wipe leaves the expedition open, so the next dive resumes a dead one")
    end },

    { name = "nothing sends a run to the Gate any more", fn = function()
        -- The screen used to be handed the expedition the company had just left, which is how it knew
        -- what floor to offer next. There is no such thing now: it opens a fresh one. A caller still
        -- passing `run` would be handing over a rift that has been closed.
        local src = source("states/game.lua")
        assert(not src:find("run = game.descent,", 1, true),
            "a state switch still carries the closed run to the Gate")
    end },
}
