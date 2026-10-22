-- LERNA: the Lernaean Hydra and a Chain Fiend, an elite on the Crown's floor ("The Crown's Bestiary", encounter
-- pass, 2026-10-09). Named for the Hydra's home, which guarded a way down. Built at integration because the two
-- bodies were built in separate slices.
--
-- DON'T BRING SWORDS. Every edge that takes a head grows two, and the Chain Fiend hooks your fighters into reach of
-- the heads. Fire stops the regrowth (models/lerna.lua).
--
-- GET PAST THE HEADS (the objective pass, 2026-10-21): the hydra guards a way down, and anyone through to the
-- far edge wins. Swords grow heads; walking past them grows none.
--
-- NO `rung`: the underworld is the single floor under all seven circles, so the ground is the pin.
return {
    name = "Lerna",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = { "character_lernaean_hydra", "character_chain_fiend" },
    objective = {
        type = "reach", region = "far", place = "past the heads", enemy = "the hydra",
        -- NO REINFORCEMENTS: the heads are the guard. The default pressure wave draws from the opening roster,
        -- which fed the board a second hydra and lost three seeds of four; a Chain Fiend trickle in its place
        -- lost the same three. With none, the company gets past in 6-10 unit-turns, four seeds of four.
        waves = {},
    },
}
