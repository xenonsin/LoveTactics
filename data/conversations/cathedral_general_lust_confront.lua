-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- The opening of data/quests/general_lust.lua: Lust's cruelest weapon is not Charm -- she cannot take
-- Amana -- but the offer of the self the Cathedral took. Amana refuses, and the refusal is who she is.
return {
    title = "Luxuria, the Unbidden",
    cast  = { "character_general_lust", "character_amana" },

    script = {
        { "character_general_lust", "You came back. In their colors, a blade at your back. I could take the blade. I could take them.", tag = 1 },
        { "character_general_lust", "Not you. I have never once been able to take you. You know why.", tag = 2 },
        { "character_general_lust", "There is nothing left in there to hold. They emptied you, sister, the same as me. I kept what I took. You gave yours away, so that no one ever could.", tag = 3 },
        { "character_general_lust", "So let me give, for once. The one thing you never let yourself want back.", tag = 4 },
        { "character_general_lust", "I know the name you were born with -- before the cloth, before they renamed you for a virtue you could be worked to death inside. Kneel, and it is yours again.", tag = 5 },
        { "character_amana", "...", tag = 6 },
        { "character_amana", "That name is not yours to give. Taking it back from your hand would only be one more theft.", tag = 7 },
        { "character_amana", "I know what I am called. I gave it to myself. And that, I am keeping.", tag = 8 },
    },
}
