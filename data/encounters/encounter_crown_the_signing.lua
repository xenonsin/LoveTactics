-- THE SIGNING: two Pit Imps and one or two Lesser Archons, ordinary traffic on the Crown's floor ("The Crown's
-- Bestiary", encounter pass, 2026-10-09). A mixed fight, built at integration because its two lines were built in
-- separate slices.
--
-- WHAT BORROWED STRENGTH IS FOR. The imps put Blood Debt on your hitters, and the Archons' wisps are the best place
-- to spend it: fast kills that end before the bill arrives. Spend it badly and the debt lands on a body already hurt.
--
-- NO `rung`: the underworld is the single floor under all seven circles, so the ground is the pin.
local Band = require("models.band")

return {
    name = "The Signing",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        return Band.fill({ "character_pit_imp", "character_pit_imp" }, ctx, "character_lesser_archon",
            { base = 1, min = 1, max = 2 })
    end,
}
