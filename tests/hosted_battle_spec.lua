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
            local reset = between(src, "game.activePanel = nil", "game.battle = nil")
            assert(reset:find("game.complete = false", 1, true),
                "the enter reset block was not found where it was")
            assert(reset:find("game.battle = nil", 1, true),
                "states/game.lua's enter does not clear game.battle -- a floor can open inside a fight "
                .. "that some other route left behind")
        end,
    },
    {
        name = "the wipe clears the fight it lost, like every other way out of one",
        fn = function()
            local src = source()
            -- The rout: the branch that drops the haul, puts the floor away and hands the company to
            -- the Gate. Read from the pack drop to the switch that leaves.
            local wipe = between(src, "Descent.dropPack(game.descent, floor", "State.switch(require(\"states.gate\")")
            assert(wipe:find("Descent.keepFloor", 1, true),
                "the wipe branch was not found where it was -- re-anchor this case rather than deleting it")
            assert(wipe:find("game.battle = nil", 1, true),
                "the wipe leaves states/game.lua holding the battle it just lost: walking back down the "
                .. "stair drops the company into the arena they were routed in")
        end,
    },
    {
        name = "every exit from a hosted battle clears it",
        fn = function()
            -- The census, so an eighth route cannot quietly join the six. Each `game.battle = Battle`
            -- opens one; each `game.battle = nil` closes one. There is exactly one opener, and the
            -- closers are the six outcomes plus the wipe plus the door.
            local src = source()
            local opens, closes = 0, 0
            for line in (src .. "\n"):gmatch("([^\n]*)\n") do
                if line:find("game.battle = Battle", 1, true) then opens = opens + 1 end
                if line:find("game.battle = nil", 1, true) then closes = closes + 1 end
            end
            assert(opens == 1, "a hosted battle should be opened in exactly one place, found " .. opens)
            assert(closes >= 8, "only " .. closes .. " routes clear game.battle -- there were eight "
                .. "(six outcomes, the wipe, and the door). A new way out of a fight needs one too")
        end,
    },
}
