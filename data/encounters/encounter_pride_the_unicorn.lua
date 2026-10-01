-- THE UNICORN: Pride's one-off elite of the worthy, on the spire's approach ("Pride's Bestiary", 2026-09-30;
-- data/characters/character_unicorn.lua). Met again on the next trip, somewhere else, as every elite is, and
-- the same fight wherever: its rule reads who is standing in front of it, never what happened last time.
--
-- WITH A BAND OF GILDED PAGES, rolled off the fight's seed: the horn cleanses its SIDE, and alone that side is
-- one body. The pages give the cleanse something to wash and the company something to spend control on.
--
-- Spire-locked, no depth gate (the circle is the placement); `rung = 1` is an exact lock for an elite. Played
-- out, never walked off (the kill-all keeps it off auto-resolve).
local Band = require("models.band")

return {
    name = "The Unicorn",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "spire" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_unicorn" }, ctx, "character_gilded_page", { base = 2, per = 6 })
    end,
    objective = { type = "killAll" },
}
