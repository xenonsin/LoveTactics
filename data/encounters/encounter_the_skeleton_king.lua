-- THE SKELETON KING, and the court he was buried with.
--
-- `elite`, so the board draws him at the top of its scale and Arena.ELITE_CAP gives the fight the room
-- it needs -- which it needs more than any other elite in the game, because this board GROWS: the King
-- puts two more bodies on his own flanks every time his call comes off cooldown
-- (data/items/ability/ability_call_the_court.lua), and a company that has not been clearing is standing
-- in a room that has been filling up behind it.
--
-- THE OPENING COURT IS THE FIGHT'S FIRST SENTENCE. Three subjects, which is ninety mana on the King's
-- bar before anybody has moved (data/traits/trait_court_of_bone.lua) -- so the very first thing a player
-- can see about this boss is a blue bar three times the size of the Barrow Lord's, on a body wearing a
-- version of the rule they have already met once. The archer is in there so that clearing the court is
-- not simply a matter of walking forward.
--
-- `minDay = 22` and the underworld: a full ten days behind the Lord
-- (data/encounters/encounter_the_barrow_lord.lua, minDay 12) and nineteen behind the common dead
-- (encounter_the_bone_orchard.lua, minDay 3), so the ladder is walked in order -- which weapon, then
-- which bar, then which body -- and each rung has been taught somewhere cheaper before it is charged
-- for.
--
-- KILLALL, WHICH IS THE DEFAULT AND MUST STAY IT. The King is emphatically not an `assassinate` mark:
-- that objective ends the fight the instant the named body falls, and this is the one fight in the game
-- where the named body falling is not the end of anything.
return {
    name = "The Skeleton King",
    kind = "elite",
    -- Rare. It is the bottom of the barrows, not the traffic in them.
    weight = 2,
    minDay = 22,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        return {
            "character_the_skeleton_king",
            "character_skeleton_knight", "character_skeleton_knight",
            "character_skeleton_archer",
        }
    end,
}
