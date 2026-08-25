-- THE GATE ALWAYS OFFERS A WAY FORWARD.
--
-- Two things can happen at the mouth of the stair and each has a condition on it: you may DESCEND while
-- somebody is picked and not in a bed (Gate.canDescend), and you may WAIT A DAY while somebody is in
-- one -- the wait draws nowhere else, because waiting mends nobody who is not lodged and a button that
-- spends a day for nothing is a button that only loses.
--
-- THOSE TWO CONDITIONS MUST COVER EVERY STATE BETWEEN THEM, and it is not obvious that they do. The
-- company is seven at most; an expedition takes four and a bed takes as many as the purse allows, so a
-- player can absolutely arrive at a morning with nobody healthy and nothing to send. If BOTH controls
-- were hidden there, the Gate would be a room with a stair you cannot take and a bed you cannot wait
-- out -- a softlock reachable by ordinary play, at the exact moment the player is already losing.
--
-- The cover is structural rather than lucky: descending needs an unlodged body and waiting needs a
-- lodged one, so the only way to hide both is to hold neither, which is an empty roster -- and the
-- avatar cannot be lost (it is `startingRoster` and nothing removes it). This file is what stops a
-- later change to either condition quietly opening the gap.

local Gate = require("models.gate")
local Wound = require("models.wound")
local Player = require("models.player")
local Descent = require("models.descent")

-- Can the Gate's "Wait a day" row draw? Mirrors states/gate.lua's own test, which is the point: if that
-- condition is edited, this file has to be edited with it, and the case below says why.
local function canWait(player)
    return #Gate.lodged(player) > 0
end

local function company(n)
    local p = Player.new()
    p.gold = 100000
    local filler = { "character_saber", "character_kaya", "character_gyeom", "character_clem",
                     "character_amana", "character_ren" }
    local i = 1
    while #p.roster < n and i <= #filler do
        Player.recruit(p, filler[i])
        i = i + 1
    end
    return p
end

local function hurt(player, id, n)
    for _ = 1, (n or 1) do Wound.inflict(player, { { id = id } }) end
end

return {
    {
        name = "a company with nobody in a bed can always descend",
        fn = function()
            local p = company(7)
            local run = Descent.new(p, 11)
            assert(Gate.canDescend(p, run), "an unpicked company takes the first four")

            -- ...and wounded is not the same as unavailable: a hurt body may still be sent, which is
            -- the whole choice the wound meter offers.
            for _, char in ipairs(p.roster) do hurt(p, char.id, 3) end
            assert(Gate.canDescend(p, run), "a company of walking wounded may still go down")
            assert(not canWait(p), "and is offered no wait, because a wait would mend nobody")
        end,
    },
    {
        -- THE STATE THE WHOLE FILE IS ABOUT: everybody in a bed. The stair shuts, and the wait is what
        -- is left -- which is the correct pair, because the days ARE the way out of this.
        name = "a company entirely in beds cannot descend, and can wait",
        fn = function()
            local p = company(7)
            local run = Descent.new(p, 12)
            for _, char in ipairs(p.roster) do
                hurt(p, char.id, 1)
                assert(Gate.lodge(p, char.id), "everybody takes a bed")
            end

            assert(#Descent.party(run, p) == 0, "nobody is available to go down")
            assert(not Gate.canDescend(p, run), "so the stair does not open")
            assert(canWait(p), "and the wait is offered, which is the way out")
        end,
    },
    {
        -- The cover, stated as the invariant rather than as two cases: whatever is lodged and whatever
        -- is picked, at least one of the two controls draws.
        name = "every arrangement of beds leaves at least one way forward",
        fn = function()
            local p = company(7)
            local run = Descent.new(p, 13)
            for _, char in ipairs(p.roster) do hurt(p, char.id, 1) end

            for i = 0, #p.roster do
                -- Empty the Inn, then put the first `i` of them back in it.
                for _, char in ipairs(p.roster) do Gate.checkout(p, char.id) end
                for k = 1, i do Gate.lodge(p, p.roster[k].id) end

                local forward = Gate.canDescend(p, run) or canWait(p)
                assert(forward, i .. " in beds and the Gate offers nothing at all")
            end
        end,
    },
    {
        -- AND IT HOLDS WITH A PICK STANDING. A party chosen before somebody was put to bed must not be
        -- able to strand the company: Descent.party filters the lodged out, so the pick degrades rather
        -- than pointing at bodies that cannot go.
        name = "a stale pick full of lodged bodies still leaves a way forward",
        fn = function()
            local p = company(7)
            local run = Descent.new(p, 14)
            for _, char in ipairs(p.roster) do hurt(p, char.id, 1) end

            local four = {}
            for k = 1, 4 do four[k] = p.roster[k].id end
            Descent.setParty(run, four)
            for k = 1, 4 do Gate.lodge(p, four[k]) end

            assert(#Descent.party(run, p) == 0, "the pick names four bodies who are all in beds")
            assert(not Gate.canDescend(p, run), "so it cannot be walked down")
            assert(canWait(p), "and the wait is there instead")

            -- ...and taking one back out re-opens the stair without the pick being touched.
            Gate.checkout(p, four[1])
            assert(Gate.canDescend(p, run), "one body back on their feet re-opens the stair")
        end,
    },
}
