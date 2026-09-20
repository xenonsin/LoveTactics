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
-- `minDay = 12` and the underworld: comfortably behind the common version
-- (data/encounters/encounter_the_bone_orchard.lua, minDay 3), so the damage-type lesson has been taught
-- somewhere cheap before the rule is stacked on top of it -- and gated to the stratum that owns it.
--
-- KILLALL, WHICH IS THE DEFAULT AND MUST STAY IT. The Lord is emphatically not an `assassinate` mark:
-- that objective ends the fight the instant the named body falls, and the instant this body falls is
-- the instant the fight becomes about anything.
return {
    name = "The Barrow Lord",
    kind = "elite",
    weight = 3,
    minDay = 12,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        return { "character_barrow_lord", "character_skeleton_knight", "character_skeleton_knight" }
    end,
}
