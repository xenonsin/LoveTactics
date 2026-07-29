-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 8 intro (data/quests/colosseum/slot_08_naming_the_day.lua). The break. Saber has deferred for
-- seven quests -- patient, which is her whole virtue, and which from outside has started to look like
-- waiting for permission. Here she STOPS. She walks into the house that schedules Ira and asks for the
-- match, out loud, in front of people, and names the day. The house cannot say yes and cannot say what
-- Ira is, so it MATCHES her instead -- against the fighter it keeps for people who ask questions in public.
--
-- This is where patience becomes a CHOICE rather than a temperament -- the difference the whole foil
-- rests on. Waiting and choosing look identical from outside and are opposite things.
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "Naming the Day",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber stops waiting -- in front of people, she asks the house for the match with Ira and names the day, out loud.", tag = 1 },
        } },
        { "colosseum", "BEAT: the house cannot say yes and cannot say what Ira is, so it answers the only way it has -- it matches her, against the fighter it keeps for people who ask questions in public.", tag = 2 },
        { "character_avatar", "BEAT: the avatar registers that a question just got answered with a bout, and that Saber chose this moment on purpose.", tag = 3 },
    },
}
