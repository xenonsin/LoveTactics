-- THE HOBGOBLIN'S MOB: the goblins' alpha fight, an elite on Wrath's approach (approved as pitched, 2026-09-26,
-- "The Goblins of Wrath"). The Hobgoblin names the Feud, so the company's lever is gone until it falls; a Hexer
-- keeps the mist up, and a Bugbear waits unseen on a flank. An alpha fight is a stop the player can read and
-- route around, the Matriarch's precedent.
local Band = require("models.band")

return {
    name = "The Hobgoblin's Mob",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_hobgoblin", "character_goblin_hexer", "character_bugbear" }, ctx,
            "character_goblin_cutter", { base = 2, min = 2, per = 6, max = 3 })
    end,
}
