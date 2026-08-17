-- THE SLEEPERS: the fight that teaches Sworn.
--
-- The hollow sleeper swears two of your company together when it acts, and the drift-things Halt -- so a
-- Halted body that is also Sworn drags its partner's tempo down with it. One lost turn costs two, which
-- is the circle's whole combo and is Acedia's opening announcement, met two bodies at a time.
return {
    name = "The Sleepers",
    kind = "combat",
    weight = 4,
    minDay = 4,
    condition = function(ctx) return ctx.biome == "tundra" end,
    composition = function(ctx)
        local list = { "character_hollow_sleeper", "character_drift_thing" }
        for _ = 1, 1 + math.floor((ctx.day or 1) / 16) do
            list[#list + 1] = "character_rime_gnat"
        end
        return list
    end,
}
