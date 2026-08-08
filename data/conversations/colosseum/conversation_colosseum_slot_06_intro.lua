-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 6 intro (data/quests/colosseum/slot_06_blood_in_the_sand.lua). The mirror of slot 2, and the
-- pairing is the point: at slot 2 the player WAS the warm-up; tonight the player is the DRAW, and the
-- promoter has padded THEIR undercard the same way -- as a courtesy, because that is what a house does
-- for a headliner it wants to keep. Nobody asks permission. The card is already printed.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "Blood in the Sand",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "BEAT: the promoter is warm, generous. Your name is the gate now, so we have taken care of your undercard for you.", tag = 1 },
        { "character_avatar", "BEAT: the avatar realises the padding is the same thing as slot 2, only this time it is being done FOR them, and nobody thought to ask.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber says nothing yet, but the mirror lands on both of them: the house that isn't one has started behaving like the others because they are winning.", tag = 3 },
        } },
    },
}
