-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Played OVER THE BOARD at the opening of the Demon Champion fight -- the mini-boss the flight leg
-- ends on (states/prologue.lua's FLIGHT_QUEST.objective.opening, fielded by states/battle.lua, which
-- applies the compact `overScene` staging to everything it plays). So the champion and its two imps
-- are already standing on the lane behind Rowan while she talks: the last still moment before the
-- first foe the game frames as a BOSS.
--
-- Its job is to reset the scale. Every fight before this one has been a horde -- imps that die to one
-- blow, a grunt that takes several. This one has a NAME, and Rowan says so: you do not swarm it down,
-- you cut it down, and the road home is on the far side of it. The avatar's line is the answer of
-- someone who has already walked the whole valley to get here and is not turning back at the gate.
return {
    title = "The Champion",
    cast  = { "character_knight", "character_avatar" },

    script = {
        { "character_knight", "Stop here, {name}. That one at the head of them is no imp -- it has a name where they carry none, and it leads this whole raiding party. This is the thing that has been walking the road behind us.", tag = 1 },
        { "character_avatar", "It's between us and the capital.", tag = 2 },
        { "character_knight", "It is. And it will not fall to the swarm-work that served against the rest -- it takes blows the grunts could not, and the imps beside it only want to keep us busy while it reaches you.", tag = 3 },
        { "character_avatar", "Then we cut it down and the imps stop mattering.", tag = 4 },
        { "character_knight", "Just so. Put it down and the road opens. Stay off its reach, let it come onto our line, and we end this at the gate rather than inside it. Ready when you are.", tag = 5 },
    },
}
