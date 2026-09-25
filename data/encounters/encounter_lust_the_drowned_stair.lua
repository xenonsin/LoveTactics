-- THE DROWNED STAIR: the Lust circle's APPROACH threat, and the second of the two holes closed.
--
-- Descent.SINS billed this circle's `elites.seat` to the Eyrie and named nobody at `approach`, so
-- rung 1 drew from an unnamed pool at flat ELITE_WEIGHT -- the same degradation Pride carries, marked
-- in code as owed. The Elder stands on it now, which means a company meets the coils on the way down
-- and the wings at the bottom, and the two elite stops of this stratum are its two animals rather than
-- one animal twice.
--
-- WHY THE APPROACH RATHER THAN THE SEAT, and it is not arbitrary. The Matriarch's cry takes a body's
-- turns away outright; the Elder's coil only prices them. The cheaper of the two rules belongs on the
-- floor a company walks onto first -- and, read the other way, a party that learned on this stair that
-- distance costs arrives at the Eyrie about to be compelled to cross a room.
--
-- SHE BRINGS HER OWN LINE, not the flock's. An escort of lamiae means every body on the board is
-- pulling the same direction and the slope is legible: the company is being billed for the same thing
-- from several places at once. Mixing harpies in would deliver her damage for free -- which is a real
-- and deliberate interaction on a floor that rolls both stops -- but as an AUTHORED cast it would
-- teach the coil and the wind in the same breath and neither one cleanly.
--
-- Locked to Lust's stratum by ctx.biome (the fen since the 2026-09-25 swap); billed on the circle's own floors through Descent.SINS'
-- `elites`, which is where a circle says WHICH of its two stairs a threat stands on.
local Band = require("models.band")

return {
    name = "The Drowned Stair",
    kind = "elite",
    weight = 1, -- rarest thing on the floor: the body a stratum is remembered for
    condition = function(ctx) return ctx.biome == "swamp" end,
    -- RUNG 1 -- the approach, which is where Lust bills it. The coils only PRICE a company's turns
    -- where the Matriarch's cry takes them outright, so the cheaper rule stands on the floor walked
    -- onto first. One elite, one floor: see models/encounter.lua's eligibility note.
    rung = 1,
    composition = function(ctx)
        local list = { "character_elder_lamia" }
        return Band.fill(list, ctx, "character_lamia", { base = 2, per = 5 })
    end,
}
