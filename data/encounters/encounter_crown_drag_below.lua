-- DRAG BELOW: a Chain Fiend and one or two Hellhounds, ordinary traffic on the Crown's floor ("The Crown's
-- Bestiary", encounter pass, 2026-10-09). A mixed fight, built at integration because its two lines were built in
-- separate slices.
--
-- WHERE YOU STAND. The hounds breathe fire onto the ground and heal standing in it, and the Chain Fiend hooks your
-- bodies into their reach. Keep an ally or a wall in the chain's line, and fight off the burning tiles. The Kennels
-- (encounter_crown_the_kennels) asks about the fire alone; this one adds the hook.
--
-- NO `rung`: the underworld is the single floor under all seven circles, so the ground is the pin.
local Band = require("models.band")

return {
    name = "Drag Below",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        return Band.fill({ "character_chain_fiend" }, ctx, "character_hellhound", { base = 1, min = 1, max = 2 })
    end,
}
