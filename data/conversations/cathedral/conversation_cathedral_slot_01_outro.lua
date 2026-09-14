-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- PLAYED ON THE FLOOR, THE MOMENT THE MILL IS QUIET, and this is where Amana joins: states/game.lua's
-- errand payout recruits `rewardCharacter` immediately before playing this scene, so the join banner
-- drains onto the end of it (models/conversation.lua).
--
-- IT USED TO BE THE CATHEDRAL'S DEBRIEF: the house's vendor in the city, an hour standing at a gate, an
-- invitation to come and shop at their counter. None of that can happen here. The company is standing on
-- a rift floor with the wheel just stopped, and the only two people in the room are the ones who did it.
return {
    title = "The Mill Is Quiet",
    cast  = { "character_avatar", "character_amana" },

    script = {
        { "character_amana", "It is quiet. Listen. It is not starting again.", tag = 30 },
        { "character_amana", "He was still turning the wheel. He did not know the water was gone.", tag = 31 },
        { "character_amana", "There will be more of these further down. I would rather not find the next one alone.", tag = 32 },
    },
}
