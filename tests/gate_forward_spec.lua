-- THE GATE ALWAYS OFFERS A WAY FORWARD.
--
-- WHAT THIS FILE USED TO GUARD, because the shape of the danger is worth keeping even though the danger
-- is gone. Two controls stood at the mouth of the stair, each with a condition on it: you could DESCEND
-- while somebody was picked and not in a bed, and you could WAIT A DAY while somebody WAS in one. The
-- two had to cover every state between them or the Gate became a room with a stair you could not take
-- and a bed you could not wait out -- a softlock reachable by ordinary play, at the exact moment the
-- player was already losing.
--
-- BOTH THE BED AND THE WAIT ARE DELETED (models/wound.lua). A wound is a condition of the expedition
-- now and the surface ends it for free, so no body is ever unavailable, nothing is ever waiting for a
-- morning, and the gap the two conditions had to cover between them does not exist to be opened.
--
-- SO THE INVARIANT IS ONE CONTROL AND ONE CONDITION, and it is pinned here for the same reason the pair
-- was: a later change to Gate.canDescend or to Descent.party's filtering must not be able to close the
-- only door this screen has. The cover is structural rather than lucky -- every body on the roster is
-- pickable, and the avatar cannot be lost (it is `startingRoster` and nothing removes it) -- so the only
-- way to shut the stair is an empty roster, which no route reaches.

local Gate = require("models.gate")
local Wound = require("models.wound")
local Player = require("models.player")
local Descent = require("models.descent")

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
        name = "a company can always descend, however badly hurt",
        fn = function()
            local p = company(7)
            local run = Descent.new(p, 11)
            assert(Gate.canDescend(p, run), "an unpicked company takes the first four")

            -- WOUNDED IS NOT UNAVAILABLE, and that is the whole choice the wound meter offers: a hurt
            -- body may still be sent, worse than they were. There is no longer any other kind of
            -- answer -- a body cannot be put anywhere that takes them out of the company.
            for _, char in ipairs(p.roster) do hurt(p, char.id, 3) end
            assert(Gate.canDescend(p, run), "a company of walking wounded may still go down")
            assert(#Descent.party(run, p) == Descent.PARTY_MAX,
                "and the expedition is still full: nothing strains a wounded body out of it")
        end,
    },
    {
        -- THE CASE THE OLD PAIR EXISTED FOR, asked of the one control that is left: the state where
        -- every single body is carrying the worst the ladder has. It used to shut the stair (they would
        -- all have been in beds); it must not now.
        name = "a company at the bottom of the wound ladder still has a stair",
        fn = function()
            local p = company(7)
            local run = Descent.new(p, 12)
            for _, char in ipairs(p.roster) do hurt(p, char.id, 5) end

            for _, char in ipairs(p.roster) do
                assert(Wound.healShare(p, char.id) == Wound.FLOOR,
                    char.id .. " should be floored, so this case ran at the bottom rung")
            end
            assert(#Descent.party(run, p) > 0, "somebody is available to go down")
            assert(Gate.canDescend(p, run), "so the stair opens")
        end,
    },
    {
        -- AND A STALE PICK CANNOT STRAND THE COMPANY EITHER. A party chosen earlier still names bodies
        -- who are all on the roster and all sendable, so the pick degrades to itself rather than to a
        -- hole in the line.
        name = "a pick made before the fighting still walks down after it",
        fn = function()
            local p = company(7)
            local run = Descent.new(p, 14)

            local four = {}
            for k = 1, 4 do four[k] = p.roster[k].id end
            Descent.setParty(run, four)
            for _, id in ipairs(four) do hurt(p, id, 3) end

            assert(#Descent.party(run, p) == 4, "the pick still names four bodies who can go")
            assert(Gate.canDescend(p, run), "so it can be walked down")
        end,
    },
}
