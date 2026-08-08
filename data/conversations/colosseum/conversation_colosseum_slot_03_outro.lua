-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 3 outro (data/quests/colosseum/slot_03_warlord_keep.lua). A clean, great fight, and Saber's joy
-- on full display. The line plants the joy here so it can spend it later -- the player has to see why
-- she stayed on the sand before the back half shows them the rot under the sport she loves.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "Siege of Warlord's Keep",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "character_avatar", "BEAT: the avatar marks it. That was a real bout, the best kind, fought clean.", tag = 1 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber is happier than the player has seen her. The craft, the read, the moment; this is the whole reason she never left the sand.", tag = 2 },
            { "character_saber", "BEAT: a beat of pure, unguarded trust in the sport. She has no idea yet what the arena she loves is built on, and the player is about to.", tag = 3 },
        } },
    },
}
