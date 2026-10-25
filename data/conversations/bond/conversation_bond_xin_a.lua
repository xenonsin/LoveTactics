-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE BOND SCENE, Xin AND THE AVATAR, RANK A (models/bond.lua). Played after a won fight in
-- which the pair's bond rose, BEFORE the bond card -- the conversation is the rank-up, Fire Emblem's
-- order (states/battle.lua's releaseWinCards, Bond.sceneFor). It is A: Follow-up and Stand Firm open.
--
-- A PLACEHOLDER: the order and the trigger play end to end, and every line is the author's to write.
return {
    title = "Xin: Bond A",
    cast  = { "character_xin", "character_avatar" },

    script = {
        { "character_xin", "PLACEHOLDER -- Xin's bond with you rises to A.", tag = 1 },
        { "character_avatar", "PLACEHOLDER -- the avatar answers.", tag = 2 },
    },
}
