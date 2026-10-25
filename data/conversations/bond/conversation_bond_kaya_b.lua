-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE BOND SCENE, Kaya AND THE AVATAR, RANK B (models/bond.lua). Played after a won fight in
-- which the pair's bond rose, BEFORE the bond card -- the conversation is the rank-up, Fire Emblem's
-- order (states/battle.lua's releaseWinCards, Bond.sceneFor). It is B: Trade Places and Teamwork open.
--
-- A PLACEHOLDER: the order and the trigger play end to end, and every line is the author's to write.
return {
    title = "Kaya: Bond B",
    cast  = { "character_kaya", "character_avatar" },

    script = {
        { "character_kaya", "PLACEHOLDER -- Kaya's bond with you rises to B.", tag = 1 },
        { "character_avatar", "PLACEHOLDER -- the avatar answers.", tag = 2 },
    },
}
