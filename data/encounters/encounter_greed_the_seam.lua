-- THE SEAM: a rich vein, and a crew working it -- DRUMS IN THE DEEP. Reviewed in three rounds, 2026-09-24:
-- round 1 approved "Delvers break in from below in two waves", round 2 denied the no-waves stand-in, and
-- round 3 chose to build the waves properly.
--
-- The Hornblower and the Goldsmith open the fight with a Delver or two -- the horn is the drum. Then the Delvers come UP THROUGH
-- THE FLOOR in two waves (`from = "below"`: Combat.waveArrivalTile puts them on the ring two and three
-- tiles out from the company's centre, never on an edge). Each wave commits two turns early and its
-- landing tiles are telegraphed -- the drums -- so standing on a marked tile is standing where they
-- surface. The fight is not won until both waves have come and fallen: a kill-all holding waves waits for
-- them, the rule `defend` has always kept (Combat.outcomeFor).
--
-- An objective-bearing encounter is not one the model can finish headless (EncounterBattle.eligible), so
-- The Seam is always played out, never auto-resolved. That is the price of a clock.
--
-- HOMED ON THE SEAT (rung 2).
local Band = require("models.band")
local Status = require("models.status")

local TURN = Status.TICKS_PER_TURN

return {
    name = "The Seam",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 2,
    composition = function(ctx)
        return Band.fill({ "character_dwarf_hornblower", "character_dwarf_goldsmith" }, ctx,
            "character_dwarf_delver", { base = 1, per = 6, max = 2 })
    end,
    objective = {
        type = "killAll",
        waves = {
            { at = 3 * TURN, from = "below",
              composition = function() return { "character_dwarf_delver", "character_dwarf_delver" } end },
            { at = 5 * TURN, from = "below",
              composition = function() return { "character_dwarf_delver", "character_dwarf_delver" } end },
        },
    },
}
