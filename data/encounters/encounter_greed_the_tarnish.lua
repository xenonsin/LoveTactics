local Band = require("models.band")

-- THE TARNISH: Rust Mites among the dwarves' diggers. The blades you want for the dwarf are the ones the
-- mites ruin, so the fight is won by choosing what hits what. Reviewed 2026-09-25 ("The Coin-Eaters").
--
-- A DELVER, NOT A HEARTHGUARD. The review named gilded Hearthguards; measured, a Hearthguard wall with
-- rusting mites behind it ran 29-34 unit-turns against the ordinary road's 22 (tests/skirmish_spec.lua),
-- because a sword line that is being blunted is exactly the line that cannot break a shield.
return {
    name = "The Tarnish",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    composition = function(ctx)
        -- One mite to two: measured at two fixed, the fight ran 34 unit-turns against the ordinary
        -- road's 22 (tests/skirmish_spec.lua) -- two bodies that punish the sword line behind a wall.
        return Band.fill({ "character_dwarf_delver" }, ctx, "character_rust_mite",
            { base = 1, min = 1, per = 8, max = 2 })
    end,
}
