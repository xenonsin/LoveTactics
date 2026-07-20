-- Tests for the hub-city data layer: building registry discovery, ordering and
-- prestige-based unlocking, quest discovery and availability filtering, and
-- blueprint immutability.

local Building = require("models.building")
local Quest = require("models.quest")
local Player = require("models.player")

-- Quest.available filters on the whole player (prestige, reputation, completed quests),
-- so specs build a throwaway player pinned to the prestige under test.
local function playerAt(prestige)
    local p = Player.new()
    p.prestige = prestige
    return p
end

return {
    {
        name = "building registry discovers def files by filename",
        fn = function()
            assert(Building.defs.quest_board, "quest_board missing")
            assert(Building.defs.blacksmith, "blacksmith missing")
            assert(Building.defs.alchemist, "alchemist missing")
            assert(Building.defs.market, "market missing")
        end,
    },
    {
        name = "Building.list is sorted by order",
        fn = function()
            local list = Building.list(1)
            for i = 2, #list do
                assert(list[i - 1].order <= list[i].order,
                    "list not sorted at index " .. i)
            end
            assert(list[1].id == "quest_board", "quest_board should sort first")
        end,
    },
    {
        name = "Building.list computes locked from prestige",
        fn = function()
            for _, b in ipairs(Building.list(1)) do
                -- A quest-gated door is a separate question, asked below; a bare prestige number
                -- cannot answer it, so those are locked here whatever their threshold.
                if not b.unlockQuest then
                    assert(b.locked == (1 < b.unlockPrestige),
                        b.id .. " locked flag wrong at prestige 1")
                end
            end
        end,
    },
    {
        -- Some doors are opened by a story rather than by getting richer: the Dueling Grounds are
        -- there because you once stood on the sand, not because you can afford them.
        name = "a quest-gated building stays shut until that quest is done",
        fn = function()
            local function findIn(list, id)
                for _, b in ipairs(list) do
                    if b.id == id then return b end
                end
            end

            local before = findIn(Building.list({ prestige = 9, completedQuests = {} }), "dueling_grounds")
            assert(before, "the dueling grounds should be listed even while shut")
            assert(before.locked, "no amount of prestige should open a quest-gated door")

            local after = findIn(
                Building.list({ prestige = 1, completedQuests = { arena_debut = true } }),
                "dueling_grounds")
            assert(not after.locked, "finishing the debut should open it, at any prestige")

            -- And a bare prestige number -- what every older caller passes -- cannot open one,
            -- because it has no way to know.
            assert(findIn(Building.list(9), "dueling_grounds").locked,
                "a prestige number alone should never open a quest gate")
        end,
    },
    {
        name = "quest registry discovers def files by filename",
        fn = function()
            assert(Quest.defs.bandit_ambush, "bandit_ambush missing")
            assert(Quest.defs.warlord_keep, "warlord_keep missing")
        end,
    },
    {
        name = "Quest.available filters by requiredPrestige",
        fn = function()
            local low = Quest.available(playerAt(1))
            for _, q in ipairs(low) do
                assert(q.requiredPrestige <= 1, q.id .. " should not appear at prestige 1")
            end

            local hasHard = false
            for _, q in ipairs(Quest.available(playerAt(3))) do
                if q.id == "warlord_keep" then hasHard = true end
            end
            assert(hasHard, "warlord_keep should be available at prestige 3")
        end,
    },
    {
        name = "blueprints are untouched after list/available",
        fn = function()
            Building.list(1)
            Quest.available(playerAt(3))
            assert(Building.defs.quest_board.locked == nil, "building blueprint mutated")
            assert(Building.defs.quest_board.name == "Quest Board", "building name changed")
            assert(Quest.defs.warlord_keep.id == nil, "quest blueprint mutated")
        end,
    },
}
