-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Played at the opening of the Demon Champion fight -- the mini-boss the city sweep ends on
-- (states/prologue.lua's FLIGHT_QUEST.objective.opening, fielded by states/battle.lua). Ordinary scene
-- staging, board frozen behind it, the champion and its two imps already standing on the lane.
--
-- Its job is to reset the scale. Every fight before this has been a horde. This one has a NAME: you do
-- not swarm it down, you cut it down.
--
-- IT COMMANDS NOTHING. Rowan used to call the imps a "raiding party" that it "leads", which is army
-- fiction from a draft where an army did the burning. It is the largest thing that came up out of the
-- breach, with the small ones trailing after -- not a commander the horde falls apart without.
--
-- THE LAST LINE IS THE OBJECTIVE, said in Rowan's own words: the fight is an `assassinate`, so it ends
-- when the champion goes down and not when the board clears. Whoever rewrites this scene has to leave
-- that instruction standing, or the win condition arrives unannounced.
return {
    title = "The Champion",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "Stop here, {name}. That big one has a name. The rest of them don't.", tag = 1 },
        { "character_rowan", "It won't go down the way the others did, and the small ones will throw themselves at us to keep us off it.", tag = 2 },
        { "character_rowan", "Cut it down and the rest stop mattering. Stay out of its reach and let it come to us.", tag = 3 },
    },
}
