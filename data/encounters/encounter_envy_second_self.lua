-- THE SECOND SELF, with the glass that decides what it copies.
--
-- The motes are not a screen here, they are the mechanism. Lesser Reflection takes the WEAKEST body it
-- can see, and the motes spend the fight stripping blessings to change which one that is -- so the
-- player's answer is the shape of their company rather than a target priority.
--
-- `elite`, so it opens at Arena.ELITE_CAP: at the four-body skirmish ceiling this would be the Second
-- Self and two motes, which is not enough glass for the choice to be real.
return {
    name = "The Second Self",
    kind = "elite",
    weight = 2,
    minDay = 6,
    condition = function(ctx) return ctx.biome == "desert" end,
    composition = function(ctx)
        local list = { "character_the_second_self", "character_mimic_of_ash" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_glass_mote"
        end
        return list
    end,
}
