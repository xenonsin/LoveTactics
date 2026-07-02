-- Tests for the hub-city data layer: building registry discovery, ordering and
-- prestige-based unlocking, quest discovery and availability filtering, and
-- blueprint immutability.

local Building = require("models.building")
local Quest = require("models.quest")

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
                assert(b.locked == (1 < b.unlockPrestige),
                    b.id .. " locked flag wrong at prestige 1")
            end
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
            local low = Quest.available(1)
            for _, q in ipairs(low) do
                assert(q.requiredPrestige <= 1, q.id .. " should not appear at prestige 1")
            end

            local hasHard = false
            for _, q in ipairs(Quest.available(3)) do
                if q.id == "warlord_keep" then hasHard = true end
            end
            assert(hasHard, "warlord_keep should be available at prestige 3")
        end,
    },
    {
        name = "blueprints are untouched after list/available",
        fn = function()
            Building.list(1)
            Quest.available(3)
            assert(Building.defs.quest_board.locked == nil, "building blueprint mutated")
            assert(Building.defs.quest_board.name == "Quest Board", "building name changed")
            assert(Quest.defs.warlord_keep.id == nil, "quest blueprint mutated")
        end,
    },
}
