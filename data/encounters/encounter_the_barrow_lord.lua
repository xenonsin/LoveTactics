-- THE BARROW LORD, and the two it was buried with.
--
-- `elite`, so the board draws it at the top of its scale and Arena.ELITE_CAP gives it the room the
-- fight needs -- which it needs for a reason no other elite has: this body occupies its tile three
-- separate times (data/characters/character_barrow_lord.lua), and a company that has been fighting
-- around it rather than through it is standing in the same fight it started twenty turns ago.
--
-- THE ESCORT IS THE CIRCLE'S OWN STOCK, not a screen. Two common dead say the board's other sentence
-- -- your edges do nothing here -- cheaply, while the expensive body walks over saying it again with a
-- rule attached. They also die properly, which is the contrast that makes the Lord legible: three
-- bodies take the same blows, two of them stay down, and the player is left with exactly one question
-- about the third. It is the same silhouette as the two beside it, which is what makes the difference
-- read as a RULE rather than as a bigger monster.
--
-- `depth = 6` (it read `minDay = 12` against the retired calendar) and the underworld: comfortably behind the common version
-- (data/encounters/encounter_the_bone_orchard.lua, depth 3), so the damage-type lesson has been taught
-- somewhere cheap before the rule is stacked on top of it -- and gated to the stratum that owns it.
--
-- KILLALL, WHICH IS THE DEFAULT AND MUST STAY IT. The Lord is emphatically not an `assassinate` mark:
-- that objective ends the fight the instant the named body falls, and the instant this body falls is
-- the instant the fight becomes about anything.
local Band = require("models.band")

return {
    name = "The Barrow Lord",
    kind = "elite",
    weight = 3,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "underworld" end,
    -- The lord is one body and always will be; the rank behind him is a band, so the same barrow met
    -- on two floors is not the same count twice (models/band.lua). An `elite` seats six
    -- (Arena.ELITE_CAP), which is the room the guard is allowed to grow into.
    --
    -- TWO IS THE FLOOR (`min = 2`) because the header's argument needs both of them: three bodies take
    -- the same blows and TWO of them stay down, which is what makes the Lord's third standing-up read
    -- as a rule rather than as a bigger monster. One escort is a different lesson.
    composition = function(ctx)
        local list = { "character_barrow_lord" }
        return Band.fill(list, ctx, "character_skeleton_knight", { base = 2, min = 2, per = 7 })
    end,
}
