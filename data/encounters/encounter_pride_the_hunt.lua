-- THE HUNT: the Lion and his lionesses, the pride's lesson. Approved 2026-09-30 on Pride's bestiary review.
--
-- While he stands, the lionesses cannot kill: a foe they bring to 1 is Rooted there and left for him, and he goes
-- for it first. Kill him and they kill freely; leave him and your bodies live, waiting for him. Not "The Pride" --
-- that is the wood's sabertooth fight (encounter_the_pride.lua).
--
-- THE LION'S COURT IS THIS FIGHT'S HEAVY END, NOT A SECOND BLUEPRINT. The review approved "The Hunt" (two
-- lionesses and a lion) and "The Lion's Court" (three, at a lower weight) as two stops; tests/encounter_spec.lua
-- holds one cast to one stop ("a different COUNT is not a different fight"), so the Court is the band's top:
-- two or three lionesses, rolled off the fight's own seed.
local Band = require("models.band")

return {
    name = "The Hunt",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_lion" }, ctx, "character_lioness", { base = 2, min = 2, max = 3 })
    end,
}
