-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 2 outro (data/quests/colosseum/slot_02_the_padded_card.lua). Aftermath of the padded card. The
-- crowd got its night whatever the player did; the house shrugs and the receipts clear. Saber's cost is
-- the first crack in "the sport is clean" -- the arena she loves just did that, and she is the one who
-- says so out loud.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "The Padded Card",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "BEAT: the promoter is pleased -- a good card, the receipts clear, the crowd went home fed.", tag = 1 },
        { "character_avatar", "BEAT: the avatar names what actually happened, plainly, against the promoter's ease.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber names it plainly -- the arena she loves just sold a slaughter as a warm-up; the sport was never the wrong thing, but that was.", tag = 3 },
        } },
    },
}
