-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 3 intro (data/quests/colosseum/slot_03_warlord_keep.lua). A real bout: the Warlord once fought
-- under the Colosseum's banner, and the house wants him back or brought down. This is the sport at its
-- genuine best -- the slot exists so the player SEES why Saber loves this, before the line charges it.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "Siege of Warlord's Keep",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "BEAT: the vendor gives the job -- the Warlord fought under our banner once; bring him back, or bring him down.", tag = 1 },
        { "character_avatar", "BEAT: the avatar clocks that this one is a genuine bout, a named fighter on the other side, not a culling.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber is alight -- THIS is the thing she loves: house against a fighter with a name, honest, no padding.", tag = 3 },
        } },
    },
}
