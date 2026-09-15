-- AUGMENTS: the dial on a bounty, and the only genuinely new mechanic in the board loop.
--
-- Before a posting is taken, the company may stake materials on making it worse. Each augment adds a
-- danger and raises what the ground pays, and the choice is made at the board with the whole company in
-- view, before anything commits.
--
-- WHAT THIS IS FOR, in one line: it is the risk decision the loop has never had.
--
-- Every other pressure in this game is imposed -- a floor is as deep as it is, a body hits as hard as it
-- hits. This one is CHOSEN, which is what makes it legal under the law the economy is built on
-- (docs/economy.md): a cost on recovery is a tax on needing to recover, but a cost on AMBITION is a bet.
-- A company that augments a hunt past what it can take has misjudged something rather than been charged
-- for losing, and that difference is the whole reason this exists.
--
-- PAID IN THE THING YOU ARE FARMING. Augments cost materials -- the stock the Forge spends -- so making
-- a run richer is priced against the upgrade you were saving for. That is Path of Exile's currency-into-
-- map without importing Path of Exile's currency economy, and it gives the material families a second
-- sink beside the bench.
--
-- LOST WITH THE BOUNTY. The materials go when the posting is taken, not when it is cleared, so a run
-- that ends badly ends with the stake gone. A bet you get back is not a bet.
--
-- EVERY DANGER RIDES A SEAM THAT ALREADY EXISTS, which is the rule that keeps this from becoming a
-- second parallel difficulty system (see [[import-the-idea-not-its-scope]]):
--
--   levels   -> quest.floorLevel, which is already "this fight is never easier than this"
--   fights   -> map.encounters, the stop count the generator lays down
--   elites   -> params.eliteShare, the cap on how many stops may be raised a rank
--   guard    -> the boss's own honour guard (models/bounty.lua's GUARD_BY_TIER)
--
-- A FIFTH SEAM IS DELIBERATELY UNUSED: opening the company under a status, the way a wound or a relic
-- boon is stamped at spawn. It is a real seam and it would make a good danger; it is left alone because
-- four numbers into four existing params need no new plumbing at all, and the first pass of a system
-- should not also be its first refactor.
--
-- Pure model: no love.graphics, no state switching, so it loads under the headless runner.
--
--   local ok = Augment.affordable(player, { "augment_hard_winter" })
--   Augment.pay(player, ids)              -- spends the materials, once, at the moment of taking
--   quest = Augment.apply(quest, ids)     -- folds the dangers into the descriptor

local Registry = require("models.registry")
local Player = require("models.player")

local Augment = {}

Augment.defs = Registry.load("data/augments", "data.augments")

-- HOW MANY MAY BE STAKED ON ONE POSTING. Three, and the ceiling is the point rather than a limit on
-- generosity: with no cap the honest play is to stake everything affordable every time, which turns a
-- decision into arithmetic. Three leaves a real choice about WHICH, and it keeps the worst case
-- describable -- a reader of this file can work out the most dangerous run the game can produce.
Augment.MAX_STAKED = 3

function Augment.get(id)
    return id and Augment.defs[id] or nil
end

-- What staking `ids` costs, summed, as { materialId = count }. Two of the same augment stack their cost
-- exactly as they stack their danger.
function Augment.costOf(ids)
    local total = {}
    for _, id in ipairs(ids or {}) do
        local def = Augment.get(id)
        for matId, n in pairs((def and def.cost) or {}) do
            total[matId] = (total[matId] or 0) + n
        end
    end
    return total
end

-- Can the company pay for this stake? Straight through to the Forge's own check, so a stake and a
-- forge rung answer "can I afford this" the same way and cannot drift apart.
function Augment.affordable(player, ids)
    return Player.canAffordMaterials(player, Augment.costOf(ids))
end

-- SPEND THE STAKE. Returns true if it was paid; false and nothing taken if it could not be -- the
-- all-or-nothing guarantee is Player.spendMaterials' own, which is why this reuses it rather than
-- deducting by hand.
--
-- Called at the moment the posting is TAKEN, beside Bounty.spend -- not at the payout. That is what
-- makes it a stake rather than a fee: it is already gone when the fight starts.
function Augment.pay(player, ids)
    return Player.spendMaterials(player, Augment.costOf(ids))
end

-- ROUGHLY WHAT AN AUGMENT IS WORTH, as one number: the count of everything in its cost, weighted so a
-- scarcer stock counts for more. Used only to ORDER a list -- cheapest danger first, so the board reads
-- as a ladder of ambition rather than as whatever `pairs` handed back.
--
-- Deliberately crude, and deliberately not a price: an augment has no gold cost and never will, and a
-- real price would be a second economy to keep in step with the shelf.
Augment.STOCK_WEIGHT = { material_iron_scrap = 1, material_steel_ingot = 3, material_mythril = 9 }

function Augment.weight(def)
    local total = 0
    for matId, n in pairs((def and def.cost) or {}) do
        total = total + n * (Augment.STOCK_WEIGHT[matId] or 2)
    end
    return total
end

-- The summed danger and payout of a stake, so a surface can say what it is about to do in one reading.
--
-- Returns a plain table of the same fields an augment blueprint carries, all defaulting to zero -- so a
-- caller adds without testing, and an empty stake reads as "no change" rather than as nil.
function Augment.totals(ids)
    local t = { levels = 0, fights = 0, elites = 0, guard = 0, drops = 0, gold = 0 }
    for _, id in ipairs(ids or {}) do
        local def = Augment.get(id)
        if def then
            for k in pairs(t) do t[k] = t[k] + (def[k] or 0) end
        end
    end
    return t
end

-- FOLD A STAKE INTO A QUEST DESCRIPTOR, in place, and hand it back.
--
-- Applied to the DESCRIPTOR rather than to the bounty blueprint, because the blueprint is shared data
-- and a stake belongs to one run of one posting. models/bounty.lua builds a fresh descriptor every
-- time, which is what makes that safe.
--
-- `elites` is a SHARE and the others are counts, so it is the one that is raised toward a ceiling
-- rather than added without bound: a share above one is not a share.
function Augment.apply(quest, ids)
    if not quest or not ids or #ids == 0 then return quest end
    local t = Augment.totals(ids)

    quest.floorLevel = (quest.floorLevel or 1) + t.levels

    local map = quest.map or {}
    quest.map = map
    if t.fights > 0 then
        local enc = map.encounters
        if type(enc) == "table" then
            -- Copied before it is raised: an authored posting's map table is the blueprint's own
            -- encounters spec, shared with every other run of that work.
            map.encounters = { min = (enc.min or 0) + t.fights, max = (enc.max or enc.min or 0) + t.fights,
                always = enc.always }
        else
            map.encounters = { min = (enc or 0) + t.fights, max = (enc or 0) + t.fights }
        end
    end
    if t.elites > 0 then
        map.eliteShare = math.min(1, (map.eliteShare or 0.25) + t.elites)
    end
    -- MORE BODIES AT THE END. Done by WRAPPING the objective's composition rather than by reaching into
    -- it, which is what makes it work for both shapes of posting: a synthesized hunt's composition is a
    -- closure this file knows nothing about, and an authored one's belongs to a quest blueprint.
    --
    -- The body repeated is the posting's own guard (quest.bounty.guard). A posting that names none
    -- cannot be augmented on this axis at all -- the term is skipped rather than guessed at, because
    -- inventing a body to stand at somebody else's end is worse than adding nothing.
    local filler = quest.bounty and quest.bounty.guard
    if t.guard > 0 and filler and type(map.objective) == "table" then
        local inner = map.objective.composition
        local extra = t.guard
        map.objective.composition = function(ctx)
            local Arena = require("models.arena")
            local list = Arena.resolveComposition(inner, ctx)
            local out = {}
            for i, id in ipairs(list) do out[i] = id end
            for _ = 1, extra do out[#out + 1] = filler end
            return out
        end
    end

    -- WHAT IT PAYS, carried onto the descriptor so the payout can honour it without re-reading the
    -- stake. `gold` is a multiplier and `drops` a count, which is the difference between "this run is
    -- worth more" and "this run hands over more things".
    quest.bounty = quest.bounty or {}
    quest.bounty.staked = ids
    quest.bounty.extraDrops = t.drops
    if t.gold > 0 then
        quest.rewardGold = math.floor((quest.rewardGold or 0) * (1 + t.gold))
    end

    return quest
end

return Augment
