-- Tests for models/augment.lua: the stake a company puts on a posting before taking it.
--
-- What these guard is the LAW the whole system is legal under -- a stake is a cost on ambition, never a
-- cost on failure (docs/economy.md). Every case below is a way that could quietly stop being true: a
-- stake that is refunded, one that can be paid twice, one that leaks into the blueprint it was staked
-- on, or one a reload can take back off after the fact.

local Augment = require("models.augment")
local Bounty = require("models.bounty")
local Quest = require("models.quest")
local Player = require("models.player")
local Material = require("models.material")

local PHASE0 = "bounty_bastion_relief_column"

local function richPlayer()
    local p = Player.new()
    p.completedQuests = {}
    for id in pairs(Material.defs) do Player.addMaterial(p, id, 50) end
    return p
end

return {
    {
        name = "the registry discovers augments and every one is well formed",
        fn = function()
            local n = 0
            for id, def in pairs(Augment.defs) do
                n = n + 1
                assert(def.name, id .. " has no name")
                assert(def.description, id .. " has no description")
                assert(next(def.cost or {}), id .. " costs nothing, so staking it is free")
                for matId in pairs(def.cost) do
                    assert(Material.get(matId), id .. " costs an unknown stock: " .. tostring(matId))
                end
                -- A danger that pays nothing is a punishment, and a payout with no danger is a gift.
                local danger = (def.levels or 0) + (def.fights or 0) + (def.elites or 0) + (def.guard or 0)
                local pays = (def.gold or 0) + (def.drops or 0)
                assert(danger > 0, id .. " adds no danger at all")
                assert(pays > 0, id .. " raises nothing, so nobody would ever stake it")
            end
            assert(n > 0, "no augments were discovered")
        end,
    },
    {
        name = "a stake is paid once, in full, and only if it can be afforded",
        fn = function()
            local poor = Player.new()
            poor.completedQuests = {}
            local ids = { "augment_deep_winter" }
            -- Measured before and after rather than asserted to be zero: a fresh company is not
            -- necessarily empty-handed, and what this case is about is that a REFUSED stake charges
            -- nothing -- not what the starting stock happens to be.
            local held = {}
            for matId in pairs(Augment.costOf(ids)) do held[matId] = Player.materialCount(poor, matId) end
            assert(not Augment.affordable(poor, ids), "a company with no stock could afford mythril")
            assert(not Augment.pay(poor, ids), "an unaffordable stake was paid anyway")
            for matId, before in pairs(held) do
                assert(Player.materialCount(poor, matId) == before,
                    "a refused stake still took " .. matId .. " -- it must be all or nothing")
            end

            local rich = richPlayer()
            local cost = Augment.costOf(ids)
            local before = {}
            for matId, n in pairs(cost) do before[matId] = Player.materialCount(rich, matId) end
            assert(Augment.pay(rich, ids), "an affordable stake was refused")
            for matId, n in pairs(cost) do
                assert(Player.materialCount(rich, matId) == before[matId] - n,
                    "the stake did not take exactly what it costs in " .. matId)
            end
        end,
    },
    {
        name = "staking the same danger twice doubles both the danger and the cost",
        fn = function()
            local one = Augment.totals({ "augment_hard_season" })
            local two = Augment.totals({ "augment_hard_season", "augment_hard_season" })
            assert(two.levels == one.levels * 2, "a doubled stake did not double its danger")

            local c1 = Augment.costOf({ "augment_hard_season" })
            local c2 = Augment.costOf({ "augment_hard_season", "augment_hard_season" })
            for matId, n in pairs(c1) do
                assert(c2[matId] == n * 2, "a doubled stake did not double its cost in " .. matId)
            end
        end,
    },
    {
        name = "a stake raises the level, the stop count and what the run pays",
        fn = function()
            local plain = Bounty.questFor(PHASE0)
            local staked = Bounty.stakedQuestFor(PHASE0, nil, { "augment_hard_season", "augment_long_road" })
            local t = Augment.totals({ "augment_hard_season", "augment_long_road" })

            assert(staked.floorLevel == plain.floorLevel + t.levels,
                "the stake did not raise the difficulty floor")
            assert(staked.map.encounters.min == plain.map.encounters.min + t.fights,
                "the stake did not lengthen the road")
            assert(staked.rewardGold > plain.rewardGold,
                "the stake raised the danger and not the pay")
            assert(staked.bounty.extraDrops == t.drops,
                "the stake's extra postings did not reach the descriptor")
        end,
    },
    {
        -- The trap this file exists for. An authored posting's objective is the BLUEPRINT'S OWN table,
        -- shared with every future run of that work -- so a stake that wrote into it would leave the
        -- extra bodies standing there for every unaugmented run afterwards.
        name = "a stake never leaks into the blueprint it was staked on",
        fn = function()
            local src = Quest.get("quest_bastion_slot_01")
            local beforeComposition = src.map.objective.composition
            local beforeEncounters = src.map.encounters

            Bounty.stakedQuestFor(PHASE0, nil, { "augment_kept_guard", "augment_long_road" })

            assert(src.map.objective.composition == beforeComposition,
                "the stake rewrote the quest blueprint's own objective")
            assert(src.map.encounters == beforeEncounters,
                "the stake rewrote the quest blueprint's own encounter spec")

            -- ...and a second, unstaked build comes back exactly as it always was.
            local plain = Bounty.questFor(PHASE0)
            assert(plain.floorLevel == Bounty.tierLevel(Bounty.get(PHASE0)),
                "an unstaked posting inherited a previous run's stake")
        end,
    },
    {
        -- More bodies at the end, for a posting that names a guard to repeat. One that names none is
        -- skipped rather than guessed at.
        name = "a guard stake stands more bodies at the end, where there is a body to repeat",
        fn = function()
            local Arena = require("models.arena")
            local apex
            for id, def in pairs(Bounty.defs) do
                if def.derived and def.tier == Bounty.TIER_APEX and def.guard then apex = id break end
            end
            assert(apex, "no derived apex names a guard")

            local plain = Bounty.questFor(apex)
            local staked = Bounty.stakedQuestFor(apex, nil, { "augment_kept_guard" })
            local before = #Arena.resolveComposition(plain.map.objective.composition, {})
            local after = #Arena.resolveComposition(staked.map.objective.composition, {})
            assert(after == before + Augment.totals({ "augment_kept_guard" }).guard,
                "the guard stake did not stand the bodies it charged for")
        end,
    },
    {
        name = "the number that may be staked is capped, and the cap is a real number",
        fn = function()
            assert(type(Augment.MAX_STAKED) == "number" and Augment.MAX_STAKED > 0,
                "there is no ceiling on a stake, so the honest play is to stake everything every time")
        end,
    },
}
