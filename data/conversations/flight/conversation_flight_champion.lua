-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Played at the opening of the Demon Champion fight -- the mini-boss the flight leg ends on
-- (states/prologue.lua's FLIGHT_QUEST.objective.opening, fielded by states/battle.lua). Ordinary scene
-- staging, board frozen behind it, the champion and its two imps already standing on the lane.
--
-- Its job is to reset the scale. Every fight before this has been a horde. This one has a NAME: you do
-- not swarm it down, you cut it down, and the road home is on the far side of it.
--
-- IT COMMANDS NOTHING. Rowan used to call the imps a "raiding party" that it "leads", which is army
-- fiction from the draft where an army burned Bellmere. It is the largest thing that came up out of
-- that field, with the small ones trailing after -- not a commander the horde falls apart without, but
-- the reason the horde is on this road at all. It said "your father's field" until the prologue was
-- re-premised: Bellmere was a posting, not a home, and nobody in this party is from it.
--
-- The tactical instruction still matches the objective
-- (`assassinate`): it ends when the champion goes down, not when the board clears.
return {
    title = "The Champion",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "Stop here, {name}. That one has a name. The rest don't. It's the biggest thing that came up out of Bellmere's field.", tag = 1 },
        { "character_avatar", "It's between us and the capital.", tag = 2 },
        { "character_rowan", "It is. It won't go down the way the others did, and the imps will throw themselves at us to keep us off it.", tag = 3 },
        { "character_avatar", "Then we cut it down and the imps stop mattering.", tag = 4 },
        { "character_rowan", "Then stay out of its reach, and let it come to us.", tag = 5 },
    },
}
