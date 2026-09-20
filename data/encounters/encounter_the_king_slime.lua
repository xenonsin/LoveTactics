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
-- `minDay = 14` and the swamp: comfortably behind the common body
-- (data/encounters/encounter_fen_ooze.lua, minDay 6), so the rule has been taught somewhere cheap
-- before it is charged for -- and gated to the stratum that owns it.
--
-- KILLALL, WHICH IS THE DEFAULT AND MUST STAY IT. The King is `boss = true` but is deliberately not
-- an `assassinate` mark -- that objective ends the fight the instant the named body falls, which is
-- the instant this fight starts. See data/characters/character_king_slime.lua.
return {
    name = "The King Slime",
    kind = "elite",
    weight = 2,
    minDay = 14,
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        return { "character_king_slime", "character_slime", "character_slime" }
    end,
}
