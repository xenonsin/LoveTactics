-- Quest logic. Blueprints live in data/quests/<id>.lua. `Quest.available`
-- returns the quests a player of the given prestige may take, as fresh copies
-- so the board can be sorted/mutated without touching the blueprints.

local Registry = require("models.registry")

local Quest = {}

Quest.defs = Registry.load("data/quests", "data.quests")

-- Quests whose requiredPrestige is met, ordered by requiredPrestige then name.
function Quest.available(prestige)
    prestige = prestige or 1

    local list = {}
    for id, def in pairs(Quest.defs) do
        if prestige >= (def.requiredPrestige or 1) then
            list[#list + 1] = {
                id = id,
                name = def.name,
                description = def.description,
                difficulty = def.difficulty,
                rewardGold = def.rewardGold,
                requiredPrestige = def.requiredPrestige or 1,
                map = def.map, -- overworld generation params; see models/overworld.lua
            }
        end
    end

    table.sort(list, function(a, b)
        if a.requiredPrestige ~= b.requiredPrestige then
            return a.requiredPrestige < b.requiredPrestige
        end
        return a.name < b.name
    end)
    return list
end

return Quest
