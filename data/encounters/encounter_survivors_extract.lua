-- "Get them out": a refugee has to be walked off the far edge of the board while demons try to cut
-- the road. The flight leg's second objective lesson (states/prologue.lua), teaching the `reach`
-- (extraction) win after the defend fight taught holding ground -- the same shape the Bastion's
-- siege road runs on (data/encounters/encounter_siege_*.lua), reused here for the prologue.
--
-- `weight = 0`: authored-only, placed through a quest's `map.encounters.always`.
--
-- The driver `escort`s -- it walks for the exit on its own every turn it is not swinging at something
-- in reach (models/ai.lua) -- so the fight is won by clearing its path, not by babysitting it. It
-- must both cross (`who`) and live (`protect`): fighting through is not enough, the person has to
-- actually get out.
return {
    name = "Break for the Tree Line",
    kind = "combat",
    minPrestige = 1,
    weight = 0,

    allies = { "character_caravan_driver" },

    composition = function(ctx)
        local p = ctx.prestige or 1
        local list = { "character_demon_imp", "character_demon_imp" }
        for i = 1, 1 + math.floor((p - 1) / 3) do list[#list + 1] = "character_demon_grunt" end
        return list
    end,

    objective = {
        type = "reach", region = "far",
        who = "character_caravan_driver",
        protect = "character_caravan_driver",
    },
}
