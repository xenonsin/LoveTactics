-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- PLAYED ON THE FLOOR, over the open vault. Clem joins here: states/game.lua's errand payout recruits
-- `rewardCharacter` immediately before this plays, so the join banner drains onto the end of it.
--
-- IT USED TO BE THE UNDERCROFT'S DEBRIEF: the fence in the city admitting he knew about the third door
-- and pointing at an unsigned stair off the markets. She made a division at the door, and the scene that
-- ends her ask is her keeping it, which is the half a fence would never have mentioned.
return {
    title = "The Third Door",
    cast  = { "character_avatar", "character_clem" },

    script = {
        { "character_clem", "Two keys and three doors. You did not stop when the sum came up short.", tag = 30 },
        { "character_clem", "The gold is on the floor behind me. Take all of it. I said I would not touch a coin.", tag = 31 },
        { "character_clem", "These go in the first fire we pass. Then I am with you.", tag = 32 },
    },
}
