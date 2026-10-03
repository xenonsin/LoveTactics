-- YOUR OWN FACE: a Skin-Thief and a Faceless Champion, with a soldier on some rolls. One wears the face of whoever
-- it last cut, the other the rift's champion that answers whoever stands nearest; keep the casters off the thief
-- and know the champions. Approved 2026-10-02 ("Envy's Bestiary", round 2).
--
-- Two elites and at most one soldier: with two soldiers it measured 37 unit-turns on the skirmish harness's seed
-- (tests/skirmish_spec.lua, budget 22). As built it measures 14 there, and 16-28 on three other seeds.
local Band = require("models.band")

return {
    name = "Your Own Face",
    kind = "combat",
    weight = 2,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_skin_thief", "character_faceless_champion" }, ctx,
            "character_faceless", { base = 0, min = 0, per = 6, max = 1 })
    end,
}
