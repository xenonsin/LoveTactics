-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Village",
    cast  = { { id = "elder", name = "Village Elder" }, "character_rowan" },

    script = {
        { "elder", "Fire on the eastern fields! Demons! The Demon Lord's army is here! Run for your lives!", tag = 1 },
        { "character_rowan", "To me, {name}, and stay close! We must hold and protect these people as they escape.", tag = 2 },
    },
}
