-- WHO GOES DOWN THE STAIR (models/descent.lua's party/setParty).
--
-- The expedition is four and the roster is not. That distinction did not exist while the whole company
-- walked down and the deployment phase picked four per fight -- and it is the premise models/wound.lua
-- is priced against, whose FLOOR assumes a company with no bench underground.
--
-- What this pins is the three ways the pick can be wrong: letting more than four down, losing somebody
-- who left the company between one descent and the next, and forgetting the pick across a save.

local Descent = require("models.descent")
local Player = require("models.player")
local Gate = require("models.gate")
local Save = require("models.save")
local Character = require("models.character")

-- A company of `n` bodies. The roster is whatever the player starts with, topped up with base-class
-- templates -- this file cares about counts and ids, not about who anybody is.
local function company(n)
    local p = Player.new()
    local filler = { "character_fighter", "character_knight", "character_mage", "character_hunter",
                     "character_rogue", "character_priest", "character_alchemist" }
    local i = 1
    while #p.roster < n and i <= #filler do
        if Character.defs[filler[i]] then Player.recruit(p, filler[i]) end
        i = i + 1
    end
    return p
end

local function ids(list)
    local out = {}
    for _, c in ipairs(list) do out[#out + 1] = c.id end
    return out
end

return {
    {
        -- NEVER PICKED IS NOT NOBODY. A company that has not opened the Gate's list has expressed no
        -- preference, and gating the stair on a screen they had no reason to open would be a locked
        -- door with no sign on it.
        name = "an unpicked expedition is the first four, and the stair opens",
        fn = function()
            local p = company(6)
            assert(#p.roster >= 5, "the fixture built a company worth trimming, got " .. #p.roster)

            local party = Descent.party(nil, p)
            assert(#party == Descent.PARTY_MAX,
                "an unset party is the first " .. Descent.PARTY_MAX .. ", got " .. #party)
            for i, c in ipairs(party) do
                assert(c.id == p.roster[i].id, "and it is the roster's own order at " .. i)
            end
            assert(Gate.canDescend(p, nil), "so the stair is open before anybody has chosen")
        end,
    },
    {
        name = "the pick is capped, deduped, and is what walks down",
        fn = function()
            local p = company(6)
            local run = Descent.new(p, 1)
            local all = ids(p.roster)

            -- More than the cap, with a repeat in it -- what a fast-fingered toggle could produce.
            Descent.setParty(run, { all[1], all[2], all[2], all[3], all[4], all[5], all[6] })
            local party = Descent.party(run, p)
            assert(#party == Descent.PARTY_MAX,
                "an over-full pick is clamped to " .. Descent.PARTY_MAX .. ", got " .. #party)
            local seen = {}
            for _, c in ipairs(party) do
                assert(not seen[c.id], c.id .. " is going down twice")
                seen[c.id] = true
            end
        end,
    },
    {
        -- A PARTY IS A LIST OF IDS AND THE ROSTER IS THE TRUTH. Somebody named in the pick who is no
        -- longer in the company must fall out of it, or a run walks down a hole in the line.
        name = "a pick naming somebody who has left degrades to who is really there",
        fn = function()
            local p = company(6)
            local run = Descent.new(p, 1)
            local all = ids(p.roster)
            Descent.setParty(run, { all[1], all[2], all[3] })

            run.party[#run.party + 1] = "character_nobody_at_all"
            local party = Descent.party(run, p)
            assert(#party == 3, "a ghost in the pick is not a body, got " .. #party)
            for _, c in ipairs(party) do
                assert(c.id ~= "character_nobody_at_all", "and is certainly not built")
            end
        end,
    },
    {
        -- THE STAIR CLOSES ON AN EMPTY PICK, which is the one case the old roster-only test could not
        -- see: a full company with nobody ticked is a player standing at a stair with nobody to send.
        name = "unticking everybody shuts the stair rather than opening an empty board",
        fn = function()
            local p = company(6)
            local run = Descent.new(p, 1)
            Descent.setParty(run, {})
            -- setParty with nothing means "not picked", which is the first four -- the stair stays open.
            assert(Gate.canDescend(p, run), "an empty pick reads as unpicked, not as refusing to go")

            -- ...but a pick naming only bodies who have left is a real empty expedition.
            run.party = { "character_nobody_at_all" }
            assert(#Descent.party(run, p) == 0, "nobody real is going")
            assert(not Gate.canDescend(p, run), "so the stair does not open")
        end,
    },
    {
        name = "the pick rides the run through a save",
        fn = function()
            local p = company(6)
            local run = Descent.new(p, 1)
            local all = ids(p.roster)
            Descent.setParty(run, { all[2], all[3] })
            p.descentRun = run

            local restored = Save.restore(Save.snapshot(p))
            local back = restored.descentRun
            assert(back, "the run comes back")
            local party = Descent.party(back, restored)
            assert(#party == 2, "two were picked and two come back, got " .. #party)
            assert(party[1].id == all[2] and party[2].id == all[3],
                "and they are the two who were picked, in the order they were picked")
        end,
    },
    {
        name = "the expedition is a cap on the roster, and no body is issued at the mouth",
        fn = function()
            -- CARRIED OVER FROM tests/descent_recruit_spec.lua, which is deleted with the floor slate it
            -- tested. These four claims were the half of that file that had nothing to do with
            -- recruitment, and dropping them with the rest would have quietly unpinned the shape of a
            -- company.
            assert(#Descent.startingCompany() == 0,
                "a descent issues nobody at the mouth: the company is the roster you already have")
            assert(Descent.STARTING_BODY == nil,
                "there is no starting body constant -- the descent draws from player.roster, and the "
                    .. "avatar is in it like anybody else")

            -- PARTY_MAX IS THE EXPEDITION AND NOT THE ROSTER. Three claims have worn this name and only
            -- the middle one is dead: it capped the ROSTER once (four held, ever), then it meant the
            -- BOARD, and it is now how many bodies go down the stair.
            --
            -- ASSERTED AS A BOUND RATHER THAN AS EQUAL TO MAX_FIELD, because both numbers are four and
            -- an equality could not say which fact it was pinning. What must hold is that an expedition
            -- is no larger than the board it fights on -- that a reserve is possible.
            --
            -- THE DEPLOYMENT PHASE NOW LEANS ON THIS BOUND. Its company strip is deleted: every body
            -- the phase is handed is standing before it draws a frame, and there is no card to drag a
            -- fifth one on from (ui/deploy_phase.lua, docs/deployment.md). Raise PARTY_MAX past
            -- MAX_FIELD and this assertion fires -- which is the point. The surplus would otherwise be
            -- benched by the commit with nothing on screen having offered the choice.
            assert(Descent.PARTY_MAX >= 1, "an expedition of nobody is not an expedition")
            assert(Descent.PARTY_MAX <= Player.MAX_FIELD,
                "an expedition may not be larger than the board it fights on: "
                    .. Descent.PARTY_MAX .. " vs " .. Player.MAX_FIELD)

            -- ...and the function that used to ask "is there room for one more" stays GONE rather than
            -- always returning true. Pinned as an absence because a branch that cannot be false is the
            -- shape that bug took the first time: every caller read it, every caller believed it, and
            -- the answer had stopped being a question long before anybody noticed.
            assert(Descent.hasRoom == nil,
                "Descent.hasRoom must not come back: the roster is unbounded and the question has one "
                    .. "answer")
        end,
    },
}
