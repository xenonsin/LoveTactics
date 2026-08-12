-- What a run COSTS and what it lets you leave with -- the two halves of the board's economy that the
-- generator's own specs deliberately do not touch (tests/overworld_spec.lua owns geometry,
-- tests/guarded_boon_spec.lua owns the pairing pass, tests/extraction_spec.lua owns the rollback rule).
--
-- Everything here pins a decision that was measured rather than reasoned to, so each case says what the
-- measurement was. `. board-report` regenerates every number quoted.

local Player = require("models.player")
local Character = require("models.character")
local Wound = require("models.wound")
local Item = require("models.item")
local Overworld = require("models.overworld")
local Save = require("models.save")

-- A throwaway company: `n` bodies with a health pool, nothing else. Built by hand rather than from a
-- blueprint so a balance pass to any real character cannot silently move what these cases measure.
local function company(n, max, current)
    local roster = {}
    for i = 1, (n or 1) do
        roster[i] = {
            id = "test_body_" .. i,
            name = "Body " .. i,
            stats = {
                health = { current = current or max, max = max },
                mana = { current = current or max, max = max },
            },
            inventory = {},
        }
    end
    return { roster = roster, stash = {} }
end

local function hp(player, i) return player.roster[i].stats.health.current end

local function genBoard(seed, params)
    local p = {
        seed = seed, biome = "forest", encounterCount = 8, keyCount = 0,
        encounters = {
            { kind = "combat", weight = 6 }, { kind = "elite", weight = 2 },
            { kind = "treasure", weight = 1 }, { kind = "rest", weight = 1 },
        },
        objective = { name = "Boss" },
        houseMaterial = "material_salt_iron",
    }
    for k, v in pairs(params or {}) do p[k] = v end
    return Overworld.generate(p)
end

return {
    -- -----------------------------------------------------------------------
    -- The camp refund (Player.CAMP_SHARE)
    -- -----------------------------------------------------------------------
    {
        name = "a camp gives back a share of what is missing, never the whole of it",
        fn = function()
            local p = company(1, 100, 20)
            Player.camp(p)
            local after = hp(p, 1)
            assert(after > 20, "a camp must move the bar it is shown moving, got " .. after)
            assert(after < 100, "a camp that refills to full is the hub, and the hub is elsewhere")
            -- Half of the 80 missing, which is the whole of the rule.
            assert(after == 60, "expected half the deficit back (60), got " .. after)
        end,
    },
    {
        name = "camps compound rather than reset, so a long board grinds the company down",
        fn = function()
            -- THE PROPERTY THE SHARE EXISTS FOR. A board guarantees a rest every six stops and carries
            -- ten-odd, so the company camps about twice a run; under the old full refill those two
            -- camps erased everything the fights between them cost, which is what made every winnable
            -- fight on the board free and every detour a yes. Halving a gap twice leaves a quarter.
            local p = company(1, 100, 20)
            Player.camp(p); Player.camp(p)
            assert(hp(p, 1) == 80, "two camps should close three quarters of the gap, got " .. hp(p, 1))
            assert(hp(p, 1) < 100, "no number of camps may reach full -- that is what going home is for")
        end,
    },
    {
        name = "a camp never tops a body past the line its wounds allow",
        fn = function()
            local p = company(1, 100, 10)
            p.roster[1].id = "wounded_one"
            -- Two separate calls, i.e. two bad fights. One call dedupes by id (a body that goes down
            -- twice in one battle has had one bad fight), which is why this is not a single call.
            Wound.inflict(p, { p.roster[1] })
            Wound.inflict(p, { p.roster[1] })
            local ceiling = math.floor(100 * Wound.healShare(p, "wounded_one"))
            for _ = 1, 12 do Player.camp(p) end
            assert(hp(p, 1) <= ceiling,
                string.format("a camp must honour the wound cap (%d), got %d", ceiling, hp(p, 1)))
            assert(ceiling < 100, "the fixture is wrong if two wounds do not cap below full")
        end,
    },
    {
        name = "the hub still heals whole -- only the road's refund is partial",
        fn = function()
            local p = company(2, 60, 5)
            Player.restore(p)
            assert(hp(p, 1) == 60 and hp(p, 2) == 60,
                "going home is the thing that makes a company whole; that did not change")
        end,
    },
    {
        name = "a camp moves every resource, not health alone",
        fn = function()
            local p = company(1, 40, 0)
            p.roster[1].stats.health.current = 40 -- unhurt, but drained
            p.roster[1].stats.mana.current = 0
            Player.camp(p)
            assert(p.roster[1].stats.mana.current == 20,
                "mana is spent on the road too, got " .. p.roster[1].stats.mana.current)
        end,
    },

    -- -----------------------------------------------------------------------
    -- The way out (consumable_smoke_bolt)
    -- -----------------------------------------------------------------------
    {
        name = "the Smoke Bolt is the company's charge, found in a grid or in the stash",
        fn = function()
            local p = company(1, 30)
            assert(not Player.extractCharge(p), "a company with no bolt has no way out")

            p.stash = { Item.instantiate("consumable_smoke_bolt") }
            local fromStash = Player.extractCharge(p)
            assert(fromStash and fromStash.where == "stash", "a bolt in the stash is still the company's")

            -- A GRID BEATS THE STASH, and the roster is walked in order, so which bolt gets spent is
            -- stable rather than whichever the table iterator reached first.
            p.roster[1].inventory = { Item.instantiate("consumable_smoke_bolt") }
            local fromGrid = Player.extractCharge(p)
            assert(fromGrid and fromGrid.where == "grid", "a carried bolt is reached before a stashed one")
        end,
    },
    {
        name = "spending the bolt consumes it, and a company with none cannot spend one",
        fn = function()
            local p = company(1, 30)
            assert(Player.spendExtract(p) == false, "there is nothing to spend")

            p.roster[1].inventory = { Item.instantiate("consumable_smoke_bolt") }
            assert(Player.spendExtract(p) == true, "the charge is there and must be spendable")
            -- THE CHECK AND THE SPEND ARE ONE CALL on purpose: a caller that asked "have I got one?"
            -- and then acted would be free to let the walk-out happen twice on one bolt.
            assert(Player.spendExtract(p) == false, "one bolt is one way out, not a standing permission")
            assert(not Player.extractCharge(p), "a spent bolt is not still on offer")
        end,
    },
    {
        name = "a spent stash bolt leaves the stash; a spent grid bolt keeps its cell",
        fn = function()
            local p = company(1, 30)
            p.stash = { Item.instantiate("consumable_smoke_bolt") }
            Player.spendExtract(p)
            assert(#p.stash == 0, "an emptied stash stack is cleared, as a drained draught is")

            local q = company(1, 30)
            q.roster[1].inventory = { Item.instantiate("consumable_smoke_bolt") }
            Player.spendExtract(q)
            assert(#q.roster[1].inventory == 1,
                "a grid keeps its emptied cell so a restock merges back into it")
        end,
    },
    {
        name = "the Smoke Bolt carries no ability -- it is aimed at nothing and fought with never",
        fn = function()
            local bolt = Item.instantiate("consumable_smoke_bolt")
            assert(bolt.extract == true, "`extract` is the whole contract the overworld reads")
            assert(not bolt.activeAbility,
                "a board item has no target and no speed; giving it one would put it in the turn order")
            assert(bolt.type == "consumable", "it is spent, unlike the torch, which is carried")
        end,
    },
    {
        name = "the overworld-item category has both its shapes, and they do not overlap",
        fn = function()
            -- PASSIVE (carried, spends nothing) and SPENT (consumed for one board action). The two
            -- members so far; the point of the case is that a future third has to pick a side.
            local torch = Item.instantiate("utility_torch")
            local bolt = Item.instantiate("consumable_smoke_bolt")
            assert(torch.visionRadius and not torch.extract, "the torch is the passive shape")
            assert(bolt.extract and not bolt.visionRadius, "the bolt is the spent shape")

            local p = company(1, 30)
            p.roster[1].inventory = { torch }
            assert(Player.visionRadius(p) == torch.visionRadius, "a carried torch widens the fog")
            assert(not Player.extractCharge(p), "and buys no way off the board")
        end,
    },

    -- -----------------------------------------------------------------------
    -- The post-game gate (Player.finishCampaign)
    -- -----------------------------------------------------------------------
    {
        name = "finishing the campaign is recorded, and is not the same act as carrying it forward",
        fn = function()
            local p = company(1, 30)
            p.gold, p.prestige = 0, 1
            assert(not Player.hasFinishedCampaign(p), "a fresh save has beaten nothing")

            Player.finishCampaign(p)
            assert(Player.hasFinishedCampaign(p), "clearing the last quest opens the post-game")

            -- `ngPlus` counts campaigns finished AND CARRIED FORWARD, and only the credits screen's
            -- button touches it. A player who watches the roll and goes back to the menu has still
            -- beaten the game, so gating the Descent on ngPlus would hide it from most finishers.
            assert((p.ngPlus or 0) == 0, "finishing is not by itself a New Game+")
        end,
    },
    {
        name = "New Game+ resets the campaign but never takes the post-game back",
        fn = function()
            local p = company(1, 30)
            p.gold, p.prestige, p.completedQuests = 0, 1, { some_quest = true }
            Player.finishCampaign(p)
            Player.newGamePlus(p)
            assert(next(p.completedQuests) == nil, "the quest ledger resets, as it always did")
            assert(Player.hasFinishedCampaign(p),
                "what the player has done cannot un-happen -- a door that shut on New Game+ would be "
                .. "the game taking a reward back")
        end,
    },
    {
        name = "the completion count survives a save round trip, and an older save reads as unfinished",
        fn = function()
            -- A REAL blueprint id, unlike the other cases here: Save.restore drops roster entries it
            -- cannot find in Character.defs and returns nil for an empty company, so a hand-rolled body
            -- would make this case pass or fail for a reason that has nothing to do with the field.
            local p = { roster = { Character.instantiate("character_knight") }, stash = {},
                        gold = 10, prestige = 1 }
            Player.finishCampaign(p)
            local snap = Save.snapshot(p)
            assert(snap.campaignsFinished == 1, "the count has to be persisted, or the gate resets on load")

            -- Purely additive: a save written before this field existed simply has not got it, and must
            -- load as a first run rather than as a crash or as a finished game.
            snap.campaignsFinished = nil
            assert((Save.restore(snap).campaignsFinished or 0) == 0,
                "an older save reads as never-finished, which is what it is")
        end,
    },

    -- -----------------------------------------------------------------------
    -- The board's arc (Overworld: braid, elite seating, tiers)
    -- -----------------------------------------------------------------------
    {
        name = "the deep end of a board is graded harder than the doorstep",
        fn = function()
            -- Measured over 300 rolled boards the mean tier by fifth runs 1.20 / 1.56 / 2.21 / 2.67 /
            -- 3.00 (`. board-report`). Before the arc went into PLACEMENT rather than into the label it
            -- ran 2.66 / 2.62 / 2.50 / 2.70 / 2.85 -- noise. A per-seed case cannot assert a mean, so
            -- this sums over enough seeds to be stable and asserts only the direction.
            local nearSum, nearN, farSum, farN = 0, 0, 0, 0
            for seed = 1, 40 do
                local grid = genBoard(seed)
                local dist = grid:bfsDistances(grid:startCell())
                local maxD = 1
                for _, d in pairs(dist) do if d > maxD then maxD = d end end
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local e = grid.cells[y][x].encounter
                        if e and e.tier then
                            local depth = (dist[y * 100000 + x] or 0) / maxD
                            if depth < 0.34 then nearSum, nearN = nearSum + e.tier, nearN + 1
                            elseif depth > 0.66 then farSum, farN = farSum + e.tier, farN + 1 end
                        end
                    end
                end
            end
            assert(nearN > 0 and farN > 0, "the fixture rolled no fights at one end of the board")
            local near, far = nearSum / nearN, farSum / farN
            assert(far > near + 0.5,
                string.format("the road must get harder as it runs: near %.2f, far %.2f", near, far))
        end,
    },
    {
        name = "an elite never stands on the near half of the road",
        fn = function()
            -- The seating rule, not the label. An elite on the doorstep is the failure this replaced:
            -- with rank as the whole of the tier and no depth gate, a board's worst fight was as likely
            -- to be its first as its last.
            for seed = 1, 40 do
                local grid = genBoard(seed)
                local dist = grid:bfsDistances(grid:startCell())
                local maxD = 1
                for _, d in pairs(dist) do if d > maxD then maxD = d end end
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local e = grid.cells[y][x].encounter
                        if e and e.kind == "elite" then
                            local depth = (dist[y * 100000 + x] or 0) / maxD
                            assert(depth >= 0.5, string.format(
                                "seed %d seated an elite at depth %.2f, inside the near half", seed, depth))
                        end
                    end
                end
            end
        end,
    },
    {
        name = "elites stay a minority of a board's fights however the pool is weighted",
        fn = function()
            -- ELITE_SHARE is the structural guard, so it is measured against a pool that is TRYING to
            -- flood the board -- which is exactly what encounter_elite's unbounded prestige weight did.
            local elite, fights = 0, 0
            for seed = 1, 30 do
                local grid = genBoard(seed, { encounters = { { kind = "elite", weight = 20 },
                                                             { kind = "combat", weight = 1 } } })
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        local e = grid.cells[y][x].encounter
                        if e and (e.kind == "combat" or e.kind == "elite") then
                            fights = fights + 1
                            if e.kind == "elite" then elite = elite + 1 end
                        end
                    end
                end
            end
            assert(fights > 0, "the fixture rolled no fights at all")
            assert(elite / fights < 0.5, string.format(
                "a pool weighted 20:1 toward elites still may not make them the ordinary fight (%d/%d)",
                elite, fights))
        end,
    },
    {
        name = "the board carries enough dead ends for its boons to be gateable",
        fn = function()
            -- THE MEASUREMENT THAT CORRECTED THE DIAGNOSIS. The guarded-boon shortfall was recorded for
            -- a whole pass as a shortage of fights; it was a shortage of CUT VERTICES, and the braid
            -- rate was eating them. At 0.55 a board carried 2.0 dead ends against 4.5 caches and 33% of
            -- boons were gateable at all; at Overworld.BRAID it carries ~3.9 and 73%. This pins the
            -- geometry rather than the pairing pass, which tests/guarded_boon_spec.lua already owns.
            local leaves, boards = 0, 30
            for seed = 1, boards do
                local grid = genBoard(seed)
                for y = 1, grid.rows do
                    for x = 1, grid.cols do
                        if grid:typeWalkable(grid.cells[y][x].tile)
                            and #grid:pathNeighbors(x, y) == 1 then leaves = leaves + 1 end
                    end
                end
            end
            local mean = leaves / boards
            assert(mean >= 2.5, string.format(
                "a board needs spur ends for its rewards to hang off: %.2f per board", mean))
        end,
    },
}
