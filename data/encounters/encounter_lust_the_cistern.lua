-- THE CISTERN: the Lust circle's second ordinary fight, and the one the flock does not turn up to.
--
-- IT IS THE HOLE THE CUT LEFT, CLOSED. ddaa5cda took the castle to 0 ordinary fights and 0 elites; the
-- Open Roof brought back one, and the note in Descent.SINS said the ground was owed "a second ordinary
-- fight that is not a harpy". This is that, and the "not a harpy" half is the whole brief -- a stratum
-- with one animal is a stratum with one fight in it, however many ways the encounter table cuts it.
--
-- WHY SERPENTS ARE IN A DRY KEEP: they are in the part of it that is not dry. A cistern is where a
-- stronghold keeps its water and where the drains run, and it is the one room of the Thinwall Keep
-- whose shape is a coil rather than a corridor.
--
-- THE FIGHT IS THE OPPOSITE OF THE OPEN ROOF'S, deliberately, and the two are meant to be met in
-- either order. Up there the answer is to pick your ground and hold it, because the flock spends its
-- turns taking that choice away. Down here picking ground is the trap -- every lamia on the board is
-- charging the company for the distance it keeps, and a party that plants itself has simply agreed to
-- be bitten from three tiles away. One stratum, two fights, and the lesson of each is the other one
-- read backwards.
--
-- NO ELDER HERE. She has her own stair (encounter_lust_the_drowned_stair), which is the approach
-- rung's billed threat -- so the ordinary fight teaches the string flat, and the elite one teaches
-- what a slope does to it.
--
-- Locked to the castle stratum by ctx.biome, the same gate every circle uses. NO DEPTH GATE: ITS
-- CIRCLE IS ITS PLACEMENT. A circle owns a fixed stratum, so a depth on top of that is a second
-- opinion about where this goes, and it disagrees the moment the shuffle deals Lust at another depth
-- (Descent.sinOrder).
local Band = require("models.band")

return {
    name = "The Cistern",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "castle" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    composition = function(ctx)
        local list = { "character_lamia" }
        return Band.fill(list, ctx, "character_lamia", { base = 1, per = 5 })
    end,
}
