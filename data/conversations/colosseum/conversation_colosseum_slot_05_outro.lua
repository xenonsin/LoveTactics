-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 5 outro (data/quests/colosseum/slot_05_the_intake.lua). The naming. Saber reads the ledger and
-- says plainly what it is -- not students, property: the house buys children and never lets them leave.
-- She was NEVER in it (severed program tie); she is the outsider who understands exactly what it is,
-- because freedom on the sand is the whole of what fighting means to her. After this she can no longer
-- tell herself the arena is clean. The line has spent three quests letting the player wonder what she
-- read in the Perennial's fighters; she names it here, and asks for nothing.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "The Intake",
    cast  = { "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber reads the facing pages aloud. Children in one column, wins in the other, and names it flat: this is not an academy, it is a stockyard. They are bought, not schooled; kept, not trained.", tag = 1 },
            { "character_saber", "BEAT: the thing she read in the roster, said at last. Those fighters move like people who are not allowed to leave, because they are not; the sport was never the wrong thing, but this is. She asks for nothing.", tag = 2 },
        } },
        { "character_avatar", "BEAT: the avatar lets it stand. Does not push, having just understood what the whole line was circling: the patron under the sand is what this ledger makes.", tag = 3 },
    },
}
