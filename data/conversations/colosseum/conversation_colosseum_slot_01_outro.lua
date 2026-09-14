-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- PLAYED ON THE FLOOR, the moment she goes down. Saber joins here: states/game.lua's errand payout
-- recruits `rewardCharacter` immediately before this plays, so the join banner drains onto the end of it.
--
-- IT USED TO BE THE ARENA'S DEBRIEF, and it was the last thing in her line still standing in the
-- Colosseum: she named the patron under the sand, the house's booking man invited the party to his
-- counter, and a Guild envoy explained the seven generals over the top of it. None of that is reachable
-- from a rift floor, and the envoy's lore belonged to a Quest Board the city no longer has.
--
-- WHAT IT COSTS, recorded here rather than quietly lost: the seven generals are introduced by nothing at
-- this point in the game any more, and the reckoning Saber owes the thing under the arena is planted
-- nowhere.
--
-- She does not ask to come along, because she never asks. See her `found` scene. She simply comes.
return {
    title = "The Best of It",
    cast  = { "character_avatar", "character_saber" },

    script = {
        { "character_saber", "Enough! Enough. Put it up.", tag = 30 },
        { "character_saber", "It has been years since anybody put me on my back. You read the opening. Nobody reads the opening.", tag = 31 },
        { "character_saber", "I am coming with you. Do not make it strange. Just walk.", tag = 32 },
    },
}
