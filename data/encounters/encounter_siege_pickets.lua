-- The outer ring of the investment at Highwatch (data/quests/relief_column.lua): imps posted on the
-- lower switchbacks to watch the road, not to hold it. Numerous, individually cheap, and the first
-- thing a column coming up the mountain runs into.
--
-- `weight = 0` keeps it OUT of the random pool entirely (Encounter.pool drops non-positive weights),
-- so it can never wander onto an unrelated quest's map. It reaches the board only through a quest's
-- `map.encounters.always`, which bypasses the pool (states/game.lua -> Overworld:placeEncounters).
-- That is the idiom for an encounter that belongs to one siege and nowhere else.
return {
    name = "Siege Pickets",
    kind = "combat",
    minPrestige = 1,
    weight = 0,
    composition = function(ctx)
        local list = {}
        for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do
            list[#list + 1] = "character_demon_imp"
        end
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
