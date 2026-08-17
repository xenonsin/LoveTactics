-- THE UNQUENCHED, with the swarm that feeds it.
--
-- The ember-spits are not a screen -- they are the drake's supply line. Each one you kill leaves fire,
-- and the Unquenched heals as it acts while standing in fire
-- (data/traits/trait_drinks_the_fire.lua). So the obvious opening (clear the little ones) is the losing
-- one, and the fight is about making the drake come to you across ground nothing has died on.
--
-- `elite`, so it opens at Arena.ELITE_CAP: at the four-body skirmish ceiling this would be the drake and
-- two spits, which is not enough fire for the trap to be real.
return {
    name = "The Unquenched",
    kind = "elite",
    weight = 2,
    minDay = 6,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    composition = function(ctx)
        local list = { "character_the_unquenched" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 15) do
            list[#list + 1] = "character_ember_spit"
        end
        return list
    end,
}
