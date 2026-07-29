-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 7 outro (data/quests/colosseum/slot_07_no_third_state.lua). The hope dies. Saber has been
-- carrying a version of this where Ira can be reached -- and she has just watched the player reach her
-- exactly as far as anyone can, which is not at all. This is the turn the whole line was built to
-- deliver; play it quiet.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "No Third State",
    cast  = { "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "character_avatar", "BEAT: the avatar, still standing at the bell, takes in what just happened -- there was no one to reach.", tag = 1 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber says the quiet thing -- she came in believing there was somewhere else Ira could be put, and there is not.", tag = 2 },
            { "character_saber", "BEAT: the hope goes out of her; from here she is not hoping to save Ira, she is deciding what she owes her.", tag = 3 },
        } },
    },
}
