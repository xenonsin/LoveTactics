-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 7 intro (data/quests/colosseum/slot_07_no_third_state.lua). THE TURN begins. The house has put
-- them on the sand with its patron, three quests before they may kill her -- not to win, only to survive
-- to the bell. The house SCHEDULES Ira; it does not fear or appease her; the stewards pull her off when
-- the bell says so.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "No Third State",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "BEAT: the house books them onto the patron's card. You are not expected to win; stay standing until the bell.", tag = 1 },
        { "character_avatar", "BEAT: the avatar asks what she actually IS, since nobody in the building will say it plainly.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber warns the player how the fight goes. Do not trade with her; every blow you land only wakes her, and she is sure because she has watched the patron eat challengers who tried to grind her down.", tag = 3 },
        } },
    },
}
