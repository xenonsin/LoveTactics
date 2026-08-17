-- RIFT-BORN, the apex of the Wrath circle.
--
-- It does not grow as it is cut; it makes the room smaller. Every threshold sheds a pair of ember-spits
-- (data/items/utility/utility_riftline.lua) and every spit leaves fire where it falls, so a long fight
-- ends on a board that has mostly caught alight.
--
-- The deliberate inverse of the Sated, one stratum over, which opens enormous and deflates. Two apexes,
-- two opposite readings of what a big body does as you hurt it, each true to its own sin.
return {
    name = "Rift-Born",
    kind = "elite",
    weight = 1,
    minDay = 8,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_rift_born" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_cinder_kin"
        end
        return list
    end,
}
