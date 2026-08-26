-- Tests for the ROUT: a fight lost with the company still on its feet.
--
-- Four things end a battle the party is still standing for -- an escort whose charge was killed, a
-- defend whose charge was, a control run out on the clock, and Fall Back -- and every one of them used
-- to be answered with the wipe: pack dropped on the floor, the run's coin and ore gone, the company
-- woken at the Gate. That charged a rout what a destruction costs, and it left the bodies free: the
-- wound meter reads who FELL (models/wound.lua), and a rout leaves nobody on the floor at all.
--
-- So a rout is its own exit now (states/game.lua's onLoss). It walks back onto the overworld it came
-- from keeping every find it made, and it is charged three things instead:
--
--   the state they are in   no rollback, no Player.restore -- the second attempt is made by whoever
--                           walked off the board
--   a wound on the spent    Combat.spentParty, below: alive, and under a third of the pool they can
--                           still use
--   the first-clear bonus   an errand's purse is paid once, to a company that did not have to come
--                           back (models/errand.lua's Errand.fail)
--
-- The last of those is a payout with TWO sides -- the grant and the victory screen's preview -- and a
-- preview wider than its grant promises coin that never arrives, so both are pinned here against the
-- same fixture.

local Combat = require("models.combat")
local Descent = require("models.descent")
local Errand = require("models.errand")
local Player = require("models.player")
local Quest = require("models.quest")
local Save = require("models.save")

-- A body with `max` health standing at `current`. Hand-built rather than instantiated: what
-- Combat.spentParty reads is the stat pool and the three exclusion flags, and a blueprint would bring a
-- kit and a level along that could move the ceiling out from under the assertion.
local function unit(id, max, current, extra)
    local u = {
        side = "party", alive = true,
        char = { id = id, stats = { health = { max = max, current = current } } },
    }
    for k, v in pairs(extra or {}) do u[k] = v end
    return u
end

local function ids(chars)
    local out = {}
    for _, c in ipairs(chars) do out[#out + 1] = c.id end
    table.sort(out)
    return table.concat(out, ",")
end

-- The first errand whose house pays a purse for it -- the fixture every bonus case below runs on. Read
-- out of the data rather than typed, so re-pricing a quest to nothing moves this to the next one that
-- still pays instead of failing on a number nobody changed on purpose.
local function paidErrand()
    for _, vendorId in ipairs({ "bastion", "cathedral", "arcanum", "colosseum" }) do
        for _, id in ipairs(Errand.forVendor(vendorId)) do
            if (Quest.defs[id].rewardGold or 0) > 0 then return id, Quest.defs[id] end
        end
    end
    return nil
end

return {
    { name = "spent: alive, and under a third of the pool they can still use", fn = function()
        local combat = { units = {
            unit("hale", 100, 90),      -- whole
            unit("even", 100, 34),      -- just over the line
            unit("spent", 100, 33),     -- just under it
            unit("dying", 100, 1),
        } }
        assert(ids(Combat.spentParty(combat)) == "dying,spent",
            "the line is not drawn at a third: got " .. ids(Combat.spentParty(combat)))
    end },

    { name = "spent counts nobody the wound ledger cannot remember", fn = function()
        -- The same three exclusions Combat.fallenParty makes, and for the same reason: a summon, a decoy
        -- or a body with no character behind it has no id a save will still know tomorrow, so charging
        -- one a wound writes a history against nobody.
        local combat = { units = {
            unit("real", 100, 5),
            unit("conjured", 100, 5, { summoned = true }),
            unit("mirror", 100, 5, { decoyOf = "real" }),
            unit("enemy", 100, 5, { side = "enemy" }),
            { side = "party", alive = true }, -- no char at all
        } }
        assert(ids(Combat.spentParty(combat)) == "real",
            "spentParty charged somebody it cannot remember: " .. ids(Combat.spentParty(combat)))
    end },

    { name = "spent is measured against the pool a WOUND left, not the one they used to have", fn = function()
        -- This is the whole reason it reads Combat.unreservedMax. A body carrying two wounds has 70% of
        -- its pool to be a third of (models/wound.lua's reserve, stamped as `woundShare`), so 25 of 100
        -- is over a third of what it can actually reach -- and judging it against the raw max would
        -- charge a veteran for standing exactly where a fresh recruit is charged nothing.
        local fresh = unit("fresh", 100, 25)
        local hurt = unit("hurt", 100, 25)
        hurt.char.woundShare = 0.30 -- what Wound.stamp writes for two wounds

        assert(ids(Combat.spentParty({ units = { fresh } })) == "fresh",
            "an unwounded body at a quarter is not spent")
        assert(ids(Combat.spentParty({ units = { hurt } })) == "",
            "a wounded body was charged against a pool it no longer has")
    end },

    { name = "a fallen body is not spent -- the two lists are disjoint", fn = function()
        -- states/battle.lua's lose() appends one to the other, and Wound.inflict dedupes by id, so a
        -- body appearing on both would still be charged once. But they should not overlap in the first
        -- place: spentParty asks for the LIVING, which is the half fallenParty cannot see.
        local down = unit("down", 100, 0, { alive = false, incapacitated = true })
        assert(ids(Combat.fallenParty({ units = { down } })) == "down", "the fallen were not counted")
        assert(ids(Combat.spentParty({ units = { down } })) == "", "a fallen body was counted twice")
    end },

    { name = "the first-clear bonus is spent once and never comes back", fn = function()
        local id = paidErrand()
        assert(id, "no house pays a purse for any errand -- the fixture has nothing to test")
        local p = Player.new()

        assert(not Errand.failedOnce(p, id), "a company that has lost nothing is already marked")
        assert(Errand.fail(p, id) == true, "the first failure did not take")
        assert(Errand.failedOnce(p, id), "the mark was not written")
        -- False on every failure after, so a caller can name the loss once rather than on every attempt.
        assert(Errand.fail(p, id) == false, "a second failure reported news that had already been told")
        assert(Errand.failedOnce(p, id), "a second failure cleared the mark it should have found")
    end },

    { name = "finished work cannot be failed, and finishing does not clear the mark", fn = function()
        local id = paidErrand()
        local p = Player.new()

        -- Nothing may write a mark on settled work: the bonus is already paid or already forfeit, and
        -- either way there is nothing left to spend.
        p.completedQuests = { [id] = true }
        assert(Errand.fail(p, id) == false, "an errand already finished accepted a failure")

        -- ...and the mark has to survive the completion that follows it, because the payout asks
        -- Errand.failedOnce AFTER Errand.complete has run. Clearing it on the way past would hand the
        -- bonus to the one company that had already lost it.
        local q = Player.new()
        Errand.fail(q, id)
        q.errands = { [id] = 1 }
        Errand.complete(q, id)
        assert(Errand.failedOnce(q, id), "completing the errand handed the forfeited bonus back")
    end },

    { name = "a spent bonus outlives the descent it was spent in", fn = function()
        -- Kept on the PLAYER beside `errands` and written to the save, because a descent is a thing you
        -- come back from: a company that surfaces and dives again must not find the purse waiting.
        local id = paidErrand()
        local p = Player.new()
        Errand.fail(p, id)

        local back = Save.restore(Save.snapshot(p))
        assert(Errand.failedOnce(back, id), "the mark did not survive a save round trip")

        -- ...and a save written before the field existed restores owing nothing, which is a company
        -- still due every bonus it has not yet collected. Purely additive: Save.VERSION does not move
        -- for this. Written as a real snapshot with the one key taken out rather than as an empty table,
        -- which is not a save at all and restores to nothing.
        local snap = Save.snapshot(p)
        snap.errandsFailed = nil
        local older = Save.restore(snap)
        assert(older and not Errand.failedOnce(older, id), "a save from before the mark restored marked")
    end },

    { name = "the victory screen and the payout agree about the bonus", fn = function()
        -- A preview wider than its grant promises a payout the beat never pays -- which this file has
        -- watched happen before (the Beggar's Bowl, named after every win on a lust floor and handed
        -- over at none). Both sides read Errand.failedOnce, so the two cannot drift; this holds them to
        -- it from the preview's end, which is the one the player sees.
        local id, def = paidErrand()
        local p, run = Player.new(), {}
        local spec = { questId = id }

        local before = Descent.objectiveReward(p, run, spec)
        assert(before and before.gold == def.rewardGold,
            "the preview does not name the bonus a fresh company is owed")

        Errand.fail(p, id)
        local after = Descent.objectiveReward(p, run, spec)
        assert(after, "the preview went silent about work that still pays its goods")
        assert(after.gold == 0, "the preview still promises a purse that has been spent")

        -- THE GOODS ARE NEVER WITHHELD. An errand's rewardItems are its slot's share of the line's
        -- quest-only shelf stock (tests/obtainable_spec.lua), so a failure that took them would delete
        -- items from the run rather than charge for a loss.
        assert(#after.items == #(def.rewardItems or {}),
            "a failed errand stopped promising the goods it is the only source of")
    end },

    { name = "the rout exit does its own bookkeeping", fn = function()
        -- Of the ways out of a fight, the losing one is where the bookkeeping goes unwritten -- so this
        -- reads the source rather than trusting the exit to have been finished. A rout moves both halves
        -- of the game's state (the board, and the profile), so both saves have to be on that path.
        -- Line endings normalised first: the tree is CRLF on Windows, and a pattern anchored on "\n"
        -- silently matches nothing there -- a source scan that cannot fail is not a test.
        local src = assert(love.filesystem.read("states/game.lua"), "cannot read states/game.lua")
        src = src:gsub("\r", "")
        -- Anchored between the fork's own condition and the comment that opens the wipe branch below it,
        -- rather than on a closing `end` -- the fork contains nested blocks, so the first `end` after it
        -- belongs to one of them and would cut the capture short of everything worth checking.
        local fork = src:match("%.routed then(.-)A DESCENT WIPE LEAVES")
        assert(fork, "the rout fork is gone from onLoss, no longer opens on `battle.routed`, "
            .. "or no longer sits above the wipe branch")

        for _, call in ipairs({ "Errand%.fail", "game:inflictWounds", "saveRun", "Player%.save",
                               "retreatFromEncounter", "State%.current = game" }) do
            assert(fork:find(call), "the rout exit no longer calls " .. call:gsub("%%", ""))
        end
        -- ...and it must NOT do the wipe's work. A rout that dropped the pack or cut the haul would be
        -- charging the failure twice, which is the one thing this exit exists not to do.
        for _, call in ipairs({ "dropPack", "loseHaul", "wipeRun", "State%.switch" }) do
            assert(not fork:find(call), "the rout exit charges the wipe's price: " .. call:gsub("%%", ""))
        end
    end },
}
