-- THE LONG WINTER, the apex of the Sloth circle.
--
-- It does not get stronger as it is cut; it sheds more drift-things, and a drift-thing takes turns. So
-- the escalation is a tempo escalation and the longer the fight runs the less of it is yours -- which is
-- the honest apex reading for a stratum that charges the clock rather than the body.
return {
    name = "The Long Winter",
    kind = "elite",
    weight = 1,
    minDay = 8,
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_the_long_winter" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_hollow_sleeper"
        end
        return list
    end,
}
