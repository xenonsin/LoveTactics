-- THE DRIFT LINE: the Sloth circle's ordinary traffic.
--
-- Everything here costs turns rather than health -- Freeze from the gnats, Halted from the drift. On the
-- one board where crossing is free (data/biomes/tundra.lua), that is the only tax a stratum can levy,
-- and this is it at the cheapest rung.
return {
    name = "The Drift Line",
    kind = "combat",
    weight = 5,
    minDay = 1,
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_drift_thing" }
        for _ = 1, 3 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_rime_gnat"
        end
        return list
    end,
}
