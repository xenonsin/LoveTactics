-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design, and hers is the shortest of the six. A fighter who is contented mid-bout has nothing to add
-- to an offer she already made, and no reason at all to hurry you toward it.
--
-- ONE ANSWER, like her `found` scene and for the same reason: she is not offering a choice. The decline
-- branch is gone and the single choice still carries `answer = "accept"`, which is the only answer
-- states/game.lua acts on.
return {
    title = "Somebody Worth Swinging At",
    cast  = { "character_avatar", "character_saber" },

    script = {
        { "character_saber", "Back already? I have not moved. There is nowhere I would rather be than about to start.", tag = 30 },
        { "character_saber", "Same opening. Same ground. Whenever you are ready.", tag = 31, choices = {
            { "Draw.", tag = 32, answer = "accept" },
        } },
    },
}
