-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- SCAFFOLDING -- beats, not prose. Write dialogue over the beat strings, then run
-- `& "E:\LOVE\lovec.exe" . extract-strings` to re-stamp ids.
--
-- Slot 8 outro (data/quests/colosseum/slot_08_naming_the_day.lua). Patience became a choice, and the
-- payoff is her SECOND RELIC: one strike per battle at full value regardless of the target's health,
-- whenever she chooses -- v1 let the arithmetic pick her moment; v2 gives her the moment. Patience as a
-- verb. (The relic item is not written yet; when it exists, grant it here / via the quest's rewardItems.)
--
-- COMPANION BLOCKS: add `when = { has = "character_<id>" }` blocks per companions-speak-in-every-scene;
-- colosseum_general_wrath_confront is the density model. Saber is scaffolded below.
return {
    title = "Naming the Day",
    cast  = { "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "character_avatar", "BEAT: the avatar names what changed -- for seven quests she waited; tonight she picked the moment, and that is not the same thing.", tag = 1 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "BEAT: Saber owns the distinction -- waiting was never the virtue; choosing when to commit is; and she has decided to commit.", tag = 2 },
            { "character_saber", "BEAT: the second-relic beat -- she takes / is handed the thing that lets her choose her one moment outright, instead of leaving it to the odds. (Owes Saber's 2nd relic item.)", tag = 3 },
        } },
    },
}
