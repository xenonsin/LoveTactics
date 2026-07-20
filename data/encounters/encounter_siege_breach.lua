-- What is actually leaning on Highwatch's gate (data/quests/relief_column.lua): the heavy end of the
-- besieging force, camped where the road stops climbing. An `elite` -- the last thing between the
-- column and the wards it is carrying, and the reason twelve days without salt is a countdown rather
-- than a hardship.
--
-- `weight = 0`: reachable only through a quest's `map.encounters.always`. See
-- data/encounters/encounter_siege_pickets.lua for why.
return {
    name = "The Breach Camp",
    kind = "elite",
    minPrestige = 1,
    weight = 0,
    composition = function(ctx)
        local list = {}
        for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do
            list[#list + 1] = "character_demon_grunt"
        end
        for i = 1, 2 do list[#list + 1] = "character_demon_imp" end
        return list
    end,

    -- The column rides along on every road leg, and each one is its own small escort: the
    -- driver must cross (`who`) and must live (`protect`). Fighting through is not enough --
    -- the wagons have to actually arrive, which is the whole doctrine in one board.
    allies = { "character_caravan_driver" },
    objective = {
        type = "reach", region = "far",
        who = "character_caravan_driver",
        protect = "character_caravan_driver",
    },
}
