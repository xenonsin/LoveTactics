-- THE DRIVEN MOB: orcs driving goblins ahead of them, on Wrath's approach -- one of the two mixed fights Keno picked
-- in round 1 (2026-09-26, "The Orcs of Wrath"). The Hurler drags someone in; Blood Feud sends every goblin at
-- whoever hits one; the Grunts get Proven finishing what the goblins started. Hitting a goblin to stop it points
-- the whole mob at you, which is exactly where the Grunts want you.
local Band = require("models.band")

return {
    name = "The Driven Mob",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_orc_spear_hurler", "character_orc_grunt", "character_orc_grunt" }, ctx,
            "character_goblin_cutter", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
