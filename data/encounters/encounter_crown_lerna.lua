-- LERNA: the Lernaean Hydra and a Chain Fiend, an elite on the Crown's floor ("The Crown's Bestiary", encounter
-- pass, 2026-10-09). Named for the Hydra's home, which guarded a way down. Built at integration because the two
-- bodies were built in separate slices.
--
-- DON'T BRING SWORDS. Every edge that takes a head grows two, and the Chain Fiend hooks your fighters into reach of
-- the heads. Fire stops the regrowth (models/lerna.lua).
--
-- NO `rung`: the underworld is the single floor under all seven circles, so the ground is the pin.
return {
    name = "Lerna",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = { "character_lernaean_hydra", "character_chain_fiend" },
}
