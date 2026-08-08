-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 9 intro (data/quests/colosseum/slot_09_what_the_house_does.lua). The approach, and the last
-- thing the player learns before the sand. The stable is cornered -- the ledger is out, the day is
-- named, the other houses are asking -- and the quest is about what it does INSTEAD of confessing: it
-- closes the program by putting the trainers who ran the intake on a card and killing them in front of
-- a paying crowd. Legal. Sport. Nothing left to ask about by morning.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "What the House Does Instead",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "BEAT: the house, cornered, has scheduled its own trainers onto a disposal card. Framed as ordinary sport, so by morning there is nothing left to ask about.", tag = 1 },
        { "character_avatar", "BEAT: the avatar clocks the move. The house will spend anyone, including its own architects, before it says one true sentence; the player is the only one trying to stop it.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber goes because it is the same crime one more time. The house feeding the sand people who never chose to be there, and she will not let it be a show. The last quiet before the sand.", tag = 3 },
        } },
    },
}
