-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 4 outro (data/quests/colosseum/slot_04_the_perennial_roster.lua). Saber has fought Perennial
-- fighters house-to-house for years and called every opening before it happened -- she knows the house
-- style cold. What she will not yet say is the uglier thing she read in HOW they fight. Slot 5 (the
-- intake) is where she names it; here she only deflects.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "The Perennial's Roster",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "character_avatar", "BEAT: the avatar notes it aloud -- they fought identically, none flinched, none celebrated.", tag = 1 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber called all four openings before they came; the player asks how she knew.", tag = 2 },
            { "character_saber", "BEAT: she deflects -- circling something she is not ready to say -- and the not-answering is louder than an answer.", tag = 3 },
        } },
    },
}
