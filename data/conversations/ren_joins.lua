-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Given Away",
    cast  = { "character_avatar", "character_ren" },

    script = {
        { "character_ren", "You could have finished me and collected. You didn't. Good -- then you have already seen more than the college wants you to.", tag = 1 },
        { "character_ren", "They chase the oldest dream: to make a person from base matter. They keep failing, and the failures are people all the same. I can undo a little of it -- restore a discard, shield a batch marked for the vats. It is why they want me quiet.", tag = 2 },
        { "character_ren", "{name}. I do the Work the honest way -- I make the base noble by giving, and I keep nothing back. Let me give it to your road instead of their shelves. Take me on.", tag = 3 },
        { "character_avatar", "Then give, and let us give something back to you for once.", tag = 4 },
        { "character_ren", "...That is not how it works. But walk on. There is much to mend.", tag = 5 },
    },
}
