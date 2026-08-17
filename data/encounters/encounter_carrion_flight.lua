-- CARRION FLIGHT: birds that will not commit, and the thing waiting underneath them for somebody to
-- stop moving.
--
-- The hawks harass and never trade; the crawler is what the harassment is FOR. A party that lets a body
-- go down while it is busy swatting at range discovers that the countdown had a second interested
-- party (data/characters/character_carrion_crawler.lua).
--
-- Punishes a company with no reach, which is a real build question and one nothing on the road asks
-- often enough.
return {
    name = "Carrion Flight",
    kind = "combat",
    weight = 4,
    minDay = 2,
    composition = function(ctx)
        local list = { "character_carrion_crawler" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_hawk"
        end
        return list
    end,
}
