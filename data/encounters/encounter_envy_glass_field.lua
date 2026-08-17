-- THE GLASS FIELD: the Envy circle's ordinary traffic, and the fight that takes rather than kills.
--
-- Neither body here can put you down quickly. What they do is strip -- one blessing a swing from the
-- motes, two from the eater -- so the party that walks out is the party that walked in, minus everything
-- it had spent turns setting up.
--
-- The reason that is not merely annoying is what stands behind it on the deeper stops: Lesser Reflection
-- copies the WEAKEST body it can see, and stripping is how a body becomes weakest. This fight decides
-- who Second Water takes.
return {
    name = "The Glass Field",
    kind = "combat",
    weight = 5,
    minDay = 1,
    condition = function(ctx) return ctx.biome == "desert" end,
    composition = function(ctx)
        local list = { "character_glass_eater" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_glass_mote"
        end
        return list
    end,
}
