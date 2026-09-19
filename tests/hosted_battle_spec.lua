-- THE ONE INVARIANT A HOSTED BATTLE HAS: no floor opens with a fight already on it.
--
-- `states/game.lua` is a module table, so every field on it outlives a State.switch. A fight fought on
-- the floor is HOSTED -- the game state stays current and holds the battle in `game.battle`, and
-- game.update forwards to it while it is set. So a route that leaves this screen without clearing it
-- comes back INTO that fight, on whatever floor is entered next.
--
-- IT SHIPPED THAT WAY, on the losing route. There were seven ways out of a fight and six of them cleared
-- it; the seventh was the WIPE -- the party routed, the haul dropped, the floor put in the map book and
-- the state switched to the Gate with `game.battle` still pointing at the battle just lost. Walking back
-- down the stair put the company straight back into the arena they had been beaten in, with no way out
-- of it. That is the shape a failure route always fails in: the losing path is the one nobody walks
-- while building the winning one ([[failure-route-skips-bookkeeping]]).
--
-- THE CLEAR IS A CALL NOW, not an assignment: `game.endFight()`, which clears the field AND gives back
-- the logical space the fight borrowed from this screen (states/game.lua's useHandheldSpace -- a hosted
-- fight on a phone lays out in the short space and the map does not). Same invariant, one more thing
-- riding on it, and the same reason it is one function: eight exits cannot each remember two acts.
--
-- SOURCE-SCANNED RATHER THAN DRIVEN, deliberately. What is being asserted is a property of every EXIT,
-- including the ones written after this file -- and a behavioural test can only reach the exits somebody
-- thought to drive, which is precisely the set that was already correct. Reading the file catches the
-- eighth route on the day it is added.

local SRC = "states/game.lua"

local function source()
    return assert(love.filesystem.read(SRC), "should be able to read " .. SRC)
end

-- The lines of `src` between the line matching `from` and the next line matching `to`, inclusive.
local function between(src, from, to)
    local out, inside = {}, false
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        if not inside and line:find(from, 1, true) then inside = true end
        if inside then
            out[#out + 1] = line
            if #out > 1 and line:find(to, 1, true) then break end
        end
    end
    return table.concat(out, "\n")
end

return {
    {
        name = "a floor opens with no fight on it -- the state's door says so",
        fn = function()
            local src = source()
            -- The reset block every entry runs, whatever route reached it. Anchored on its two
            -- neighbours so this fails if the line is moved somewhere that does not run on every enter,
            -- rather than merely if it is deleted.
            local reset = between(src, "game.activePanel = nil", "game.endFight()")
            assert(reset:find("game.complete = false", 1, true),
                "the enter reset block was not found where it was")
            assert(reset:find("game.endFight()", 1, true),
                "states/game.lua's enter does not clear game.battle -- a floor can open inside a fight "
                .. "that some other route left behind")
        end,
    },
    {
        name = "the wipe clears the fight it lost, like every other way out of one",
        fn = function()
            local src = source()
            -- The rout: the branch that charges the count and sends the company home. It used to be
            -- anchored on the pack drop, which was the first thing it did; nothing is dropped any more,
            -- so the anchor moved to the thing a wipe now DOES -- put two marks on the tally.
            --
            -- THE CLOSING ANCHOR IS THE ROUT'S OWN NOTICE, not the state switch that follows it. It was
            -- the switch to the Gate, which was unique in this file; a wiped company wakes in the CITY
            -- now and `State.switch(require("states.hub"))` is one of half a dozen, so anchoring on it
            -- would close this window at whichever one came first. `pendingRout` is written once, in
            -- this branch, and is the last thing it does before leaving.
            local wipe = between(src, "Descent.countBy(game.player, Descent.COUNT_WIPE)",
                "game.player.pendingRout = floor")
            assert(wipe:find("Player.recordFound", 1, true),
                "the wipe branch was not found where it was -- re-anchor this case rather than deleting it")
            assert(wipe:find("game.endFight()", 1, true),
                "the wipe leaves states/game.lua holding the battle it just lost: walking back down the "
                .. "stair drops the company into the arena they were routed in")
        end,
    },
    {
        name = "every exit from a hosted battle clears it",
        fn = function()
            -- The census, so an eighth route cannot quietly join the six. Each `game.battle = Battle`
            -- opens one; each `game.endFight()` closes one. There is exactly one opener, and the
            -- closers are the six outcomes plus the wipe plus the door.
            --
            -- Comment lines are skipped: the prose at both ends of this file names the line it is
            -- counting, and a census that counts its own explanation is a census that cannot fail.
            local src = source()
            local opens, closes = 0, 0
            for line in (src .. "\n"):gmatch("([^\n]*)\n") do
                if not line:match("^%s*%-%-") then
                    if line:find("game.battle = Battle", 1, true) then opens = opens + 1 end
                    if line:find("game.endFight()", 1, true) then closes = closes + 1 end
                end
            end
            assert(opens == 1, "a hosted battle should be opened in exactly one place, found " .. opens)
            assert(closes >= 8, "only " .. closes .. " routes call game.endFight -- there were eight "
                .. "(six outcomes, the wipe, and the door). A new way out of a fight needs one too")
        end,
    },
    {
        name = "a fight the meter dealt comes off the board however it ends",
        fn = function()
            -- THREE WAYS A ROLLED FIGHT ENDS WELL -- fought, walked off, broken away from -- and all
            -- three have to take it off the tile, because it was never a place: Descent.wander writes it
            -- onto whatever square the company was standing on when the meter topped out. A cleared
            -- marker left behind draws crossed swords over empty corridor, and the next trip down WAKES
            -- it (Descent.rearmFloor) as seated combat on a floor that seats none.
            --
            -- Only the flee path did it for a while, which is the ordinary shape of this bug: the route
            -- somebody drove while building the feature is the one that learned the rule.
            --
            -- A ROUT IS NOT ON THE LIST, deliberately. Losing leaves the fight standing and uncleared,
            -- the same as a seated one, so walking back onto the tile asks the same question again.
            local src = source()
            local defs, calls = 0, 0
            for line in (src .. "\n"):gmatch("([^\n]*)\n") do
                if not line:match("^%s*%-%-") and line:find("retireRolledFight", 1, true) then
                    if line:find("local function", 1, true) then defs = defs + 1 else calls = calls + 1 end
                end
            end
            assert(defs == 1, "the rolled fight should be retired through exactly one seam, found "
                .. defs .. " -- two copies is how one of them forgets")
            assert(calls >= 3, "only " .. calls .. " of the three good ends to a rolled fight take it "
                .. "off the board (fought, walked off, fled); the rest leave a marker standing on a "
                .. "tile nothing happened on, and rearmFloor will wake it")
        end,
    },
}
