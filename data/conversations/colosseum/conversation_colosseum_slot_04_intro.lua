-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 4 intro (data/quests/colosseum/slot_04_the_perennial_roster.lua). The escalation: the reigning
-- stable puts four of its own on the card. They fight identically, none of them flinch, none celebrate.
-- The player does not learn WHY here -- just fights four of them and notices they are not quite people.
-- (The fighters deliberately do not speak, so there is no confront scene; the unease lives here.)
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "The Perennial's Roster",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "BEAT: the vendor puts the reigning house's four on the card -- the stable that wins, and has for longer than anyone finds strange.", tag = 1 },
        { "character_avatar", "BEAT: the avatar sizes them up -- watch how they fight; watch how they do not celebrate.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber goes quiet the moment she sees them -- she reads the house style cold, but it is HOW they move that unsettles her: like people not allowed to want anything. She will not name it yet.", tag = 3 },
        } },
    },
}
