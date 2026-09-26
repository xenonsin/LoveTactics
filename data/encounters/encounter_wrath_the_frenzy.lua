-- THE FRENZY: an orc Berserker in a goblin Hexer's mist, on Wrath's seat -- the second of the two mixed fights
-- (2026-09-26, "The Orcs of Wrath"). Wrath's "no control" twice over: the Red Mist rolls a random action for
-- anyone inside it, and the Berserker has to swing every turn anyway. A Berserker in the mist can hit the Hexer,
-- and a company body in it can hit the Berserker and start its streak.
local Band = require("models.band")

return {
    name = "The Frenzy",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_orc_berserker", "character_goblin_hexer" }, ctx,
            "character_goblin_cutter", { base = 2, min = 1, per = 6, max = 3 })
    end,
}
