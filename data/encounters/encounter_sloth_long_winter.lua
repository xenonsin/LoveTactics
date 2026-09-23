-- THE LONG WINTER, the apex of the Sloth circle.
--
-- It does not get stronger as it is cut; it sheds more drift-things, and a drift-thing takes turns. So
-- the escalation is a tempo escalation and the longer the fight runs the less of it is yours -- which is
-- the honest apex reading for a stratum that charges the clock rather than the body.
local Band = require("models.band")

return {
    name = "The Long Winter",
    kind = "elite",
    weight = 1,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- WHICH of the two is `rung` below, and on an elite it is REQUIRED rather than optional: one elite,
    -- one floor. A biome lock places a body in the stratum and then leaves it standing on both of that
    -- stratum's stairs, which makes a landmark into traffic -- see models/encounter.lua's eligibility
    -- note for the whole argument, and tests/elite_floor_spec.lua for the count that holds it.
    --
    -- Descent.SINS' `elites` is the SEPARATE question of which of a floor's candidates the floor is
    -- ABOUT (billed at ELITE_NAMED_WEIGHT). The rung says where a thing may stand at all.
    condition = function(ctx) return ctx.biome == "tundra" end,
    -- RUNG 2 -- the seat, which is where Sloth bills it -- AND IT IS THE TUNDRA'S ONLY ELITE, so
    -- Sloth's approach floor now stands none at all. That hole is the one-elite-one-floor rule
    -- arriving on a circle the 2026-09-22 cut left with a single body; see Descent.SINS' entry for
    -- what a replacement owes.
    rung = 2,
    composition = function(ctx)
        local list = { "character_the_long_winter" }
        -- THE SLEEPERS ARE DELETED (2026-09-22). The ice elemental is the tundra's own surviving
        -- body; it carries no Torpor, so the escort no longer teaches what the seat does.
        return Band.fill(list, ctx, "character_ice_elemental", { base = 1, per = 6 })
    end,
}
