-- THE WOLF PACK: the cheapest honest combo in the game, and it needed no new bodies at all.
--
-- The alpha and the grunts have both existed since the first week of this project and have never stood
-- on a board together -- encounter_wolf.lua fields grunts and nothing else. Put the alpha in and the
-- fight acquires a kill order: the pack is worth more with it alive, so the correct play is to reach
-- past the teeth in front of you.
--
-- Which is the same lesson four warbands teach with people, taught here by animals on every floor.
return {
    name = "Wolf Pack",
    kind = "combat",
    weight = 5,
    minDay = 1,
    composition = function(ctx)
        local list = { "character_wolf_alpha" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 12) do
            list[#list + 1] = "character_wolf_grunt"
        end
        return list
    end,
}
