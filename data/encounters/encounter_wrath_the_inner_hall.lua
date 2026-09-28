-- THE INNER HALL (Wrath, floor 8): two or three Adepts -- the Sparring Ground's floor-8 form, so the seat deals
-- asura of its own rather than only strays from the approach (a combat's `rung` is its home). Every body here
-- spends (Flurry), so nothing on the board is a free Burst to wait out.
--
-- Approved as "an Adept and two Acolytes", which is the Sparring Ground's cast, and one cast is one stop --
-- counted by the KINDS of body, not how many (tests/encounter_spec.lua). So it is Adepts only.
local Band = require("models.band")

return {
    name = "The Inner Hall",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_asura_adept", "character_asura_adept" }, ctx,
            "character_asura_adept", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
