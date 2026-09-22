-- THE KING SLIME, and the two of its own it came in with.
--
-- `elite`, so the board draws it as the top of its scale and Arena.ELITE_CAP gives it the room a
-- four-body fight needs -- which it needs twice over here, because the King is three more bodies the
-- moment it falls (data/traits/trait_split.lua). A company that has spent the whole fight on the
-- crowned body and cleared nothing else is standing in five slimes when it dies.
--
-- The escort is the circle's own stock rather than a screen: the lesson of the fen is "how many
-- elements did you bring", and two ordinary slimes are the same question asked cheaply while the
-- expensive one is still walking over. They also adapt independently, so a caster answering the King
-- with fire is not also answering them with it.
--
-- `depth = 7` (it read `minDay = 14` against the retired calendar) and the swamp: comfortably behind the common body
-- (data/encounters/encounter_fen_ooze.lua, depth 6), so the rule has been taught somewhere cheap
-- before it is charged for -- and gated to the stratum that owns it.
--
-- KILLALL, WHICH IS THE DEFAULT AND MUST STAY IT. The King is `boss = true` but is deliberately not
-- an `assassinate` mark -- that objective ends the fight the instant the named body falls, which is
-- the instant this fight starts. See data/characters/character_king_slime.lua.
local Band = require("models.band")

return {
    name = "The King Slime",
    kind = "elite",
    weight = 2,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "swamp" end,
    -- The king is one; what it has already split off is a band (models/band.lua), floored at the two
    -- the header argues for -- they are the fen's question ("how many elements did you bring") asked
    -- cheaply while the expensive body is still walking over, and one of them cannot ask it, because a
    -- single slime adapts to a single element and the choice disappears.
    composition = function(ctx)
        local list = { "character_king_slime" }
        return Band.fill(list, ctx, "character_slime", { base = 2, min = 2, per = 7 })
    end,
}
