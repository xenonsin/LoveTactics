-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 6 outro (data/quests/colosseum/slot_06_blood_in_the_sand.lua). Complicity named. Afterward Saber
-- asks the player -- not rhetorically, she wants an answer -- whether they intend to keep taking the top
-- billing. The standing they need to reach Ira is paid for out of exactly this, and she knows it.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "Blood in the Sand",
    cast  = { "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber asks it straight -- do you mean to keep taking the top billing? -- and makes clear she wants a real answer, not a shrug.", tag = 1 },
        } },
        { "character_avatar", "BEAT: the choice is the player's, and the scene leaves it standing rather than resolving it -- the billing is how they get to Ira at all.", tag = 2 },
    },
}
