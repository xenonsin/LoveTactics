-- The investment line proper, halfway up the mountain (data/quests/relief_column.lua): grunts dug in
-- across the road with imps behind them. This is the part of a siege that is actually a siege -- not
-- a raid that wandered up, but a formation sitting on the only way in, doing the one thing the Watch
-- was built to prevent and doing it patiently.
--
-- `weight = 0`: reachable only through a quest's `map.encounters.always`. See
-- data/encounters/encounter_siege_pickets.lua for why.
return {
    name = "The Investment Line",
    kind = "combat",
    minPrestige = 1,
    weight = 0,
    composition = function(ctx)
        local list = { "character_demon_grunt" }
        for i = 1, 1 + math.floor((ctx.prestige or 1) / 3) do
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
