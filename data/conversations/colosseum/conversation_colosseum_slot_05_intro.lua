-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 5 intro (data/quests/colosseum/slot_05_the_intake.lua). THE DISCOVERY: the program, not its
-- output. The house keeps an intake ledger -- children received by year, against the roster's win
-- record on the facing page -- kept with PRIDE, because it genuinely believes it is describing an
-- academy. Nobody has hidden it. The job is to get into the hall and read it.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "The Intake",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "BEAT: the vendor points them at the intake hall -- get in and read the ledger; the stewards are in the way.", tag = 1 },
        { "character_avatar", "BEAT: the avatar registers what the ledger actually records -- children received by year, wins on the facing page, kept with pride.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber has gone very still -- she has worked out what this ledger is before they reach it, and says nothing on the way in.", tag = 3 },
        } },
    },
}
