-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- The opening of data/quests/fallen_confessor.lua: the Cathedral names its own accused, Amana answers.
return {
    title = "The Fallen Confessor",
    cast  = { "cathedral", "character_amana" },

    script = {
        { "cathedral", "The one before you wore our cloth. Confessor. Anointed. She knows the charge.", tag = 1 },
        { "cathedral", "She sheltered what was ours to reclaim, and would not give it back. That is theft from the faith. Purge her, and be paid.", tag = 2 },
        { "character_amana", "They were children. The faith did not ask them. It has never once asked.", tag = 3 },
        { "character_amana", "And now it sends you to take me. I understand. Take is the only verb they were ever taught.", tag = 4 },
        { "character_amana", "I will not step aside, and I will not strike first. Come, then.", tag = 5 },
        { "character_amana", "Take what you can. You will find I have already given it away.", tag = 6 },
    },
}
