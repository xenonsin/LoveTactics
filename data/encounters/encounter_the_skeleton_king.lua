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
-- `depth = 12` (it read `minDay = 22` against the retired calendar) and the underworld: a full ten days behind the Lord
-- (data/encounters/encounter_the_barrow_lord.lua, depth 12) and nineteen behind the common dead
-- (encounter_the_bone_orchard.lua, depth 3), so the ladder is walked in order -- which weapon, then
-- which bar, then which body -- and each rung has been taught somewhere cheaper before it is charged
-- for.
--
-- KILLALL, WHICH IS THE DEFAULT AND MUST STAY IT. The King is emphatically not an `assassinate` mark:
-- that objective ends the fight the instant the named body falls, and this is the one fight in the game
-- where the named body falling is not the end of anything.
local Band = require("models.band")

return {
    name = "The Skeleton King",
    kind = "elite",
    -- Rare. It is the bottom of the barrows, not the traffic in them.
    weight = 2,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "underworld" end,
    -- THREE SUBJECTS, ALWAYS -- AND THE ROLL MOVES THEIR SHAPE INSTEAD OF THEIR NUMBER.
    --
    -- The count here is not free the way an escort's is: trait_court_of_bone pays the King thirty mana
    -- a subject, so the opening court IS the ninety on his bar that the header calls the fight's first
    -- sentence. A band on the total would make that number roll between sixty and a hundred and
    -- twenty, and the boss the player is being shown would not be the same boss.
    --
    -- So the total is pinned and the COMPOSITION of it rolls: one bow behind two swords, or two behind
    -- one. Same mana, same three bodies, a different problem to walk into -- which is the orchard's own
    -- rule (a nastier shape, not a longer one) applied to the body that court grew up into.
    --
    -- The knights are listed before the archers because Arena.clampComposition tops a fight up from the
    -- filler IN AUTHORED ORDER, so what a ceiling takes off this fight is a bow and never the line
    -- shielding it.
    composition = function(ctx)
        local COURT = 3
        local bows = Band.count(ctx, { base = 1, min = 1, max = 2, key = "character_skeleton_archer" })
        local list = { "character_the_skeleton_king" }
        for _ = 1, COURT - bows do list[#list + 1] = "character_skeleton_knight" end
        for _ = 1, bows do list[#list + 1] = "character_skeleton_archer" end
        return list
    end,
}
