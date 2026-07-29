-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 2 intro (data/quests/colosseum/slot_02_the_padded_card.lua). The promoter warms the crowd with
-- a bout that is not one: the "opponents" are culls -- debtors, condemned -- brought to die in front of
-- people. The player can refuse the kill; the house will send its own down to fill the card either way.
-- Saber's cost this slot: the first crack in "the sport is clean." A veteran of the sand, she has
-- watched promoters run this play for years -- she knows exactly what she is looking at, is plainly
-- disgusted, and is first onto the sand between the enforcers and the culls before anyone asks.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model (full roster). Saber is scaffolded below.
return {
    title = "The Padded Card",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "BEAT: the promoter frames tonight's opener as a warm-up bout to settle the crowd.", tag = 1 },
        { "character_avatar", "BEAT: the avatar reads the far side of the sand -- these people were not brought here to fight.", tag = 2 },
        { "colosseum", "BEAT: the house cannot let the card go unfilled; the crowd was sold a night, and a night is what it gets.", tag = 3 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber already knows what this is -- she has watched promoters run it for years -- and does not look away.", tag = 4 },
            { "character_saber", "BEAT: she is going down onto the sand first -- between the enforcers and the culls -- before anyone asks her to.", tag = 5 },
        } },
        { "character_avatar", "BEAT: the choice lands on the player: swing at what is in front of you, or refuse and let the house spend its own.", tag = 6 },
    },
}
