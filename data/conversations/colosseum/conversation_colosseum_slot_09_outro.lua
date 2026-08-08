-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 9 outro (data/quests/colosseum/slot_09_what_the_house_does.lua). The last quiet before slot 10.
-- The reckoning the player carries onto the sand: killing Ira does not touch the machine. A house that
-- discovered rage outperforms morale will be training again inside a year, because the league still
-- pays for what only this house can put on the sand. The general is not the disease.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "What the House Does Instead",
    cast  = { "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "character_avatar", "BEAT: the avatar says the hard thing plainly. Killing Ira ends Ira, and nothing else; the Perennial trains again within a year.", tag = 1 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber does not argue it. She knows, and reframes what they are actually going down there to do, and for whom.", tag = 2 },
            { "character_saber", "BEAT: the last quiet before slot 10. She is done deferring and done hoping; what is left is what she owes Ira.", tag = 3 },
        } },
    },
}
