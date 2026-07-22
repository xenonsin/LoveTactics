-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- The opening of data/quests/general_lust.lua: Lust's cruelest weapon is not Charm -- she cannot take
-- Amana -- but the offer of the self the Cathedral took. Amana refuses, and the refusal is who she is.
-- Luxuria is NOT Amana's kin: she is a human who pacted with the Demon Lord and infiltrated the
-- Cathedral as its Saint. Amana is an unblooded acolyte, so there is nothing of Luxuria in her to
-- command -- her refusal of the name is a choice, not an immunity. See docs/story.md, "The Cathedral".
return {
    title = "Luxuria, the Unbidden",
    cast  = { "character_general_lust", "character_amana" },

    script = {
        { "character_general_lust", "The little witness -- come back in their colors, a blade at your back. You saw the pits and could not look away, and here you are anyway. I never once feared you would come.", tag = 1 },
        { "character_general_lust", "I can take the blade. I can take every soul in these colors. But not you. There was never any of me put in you to call.", tag = 2 },
        { "character_general_lust", "You were the one we kept clean. No blooding, no leash. I used to think that a waste. Today I find it a mercy I can still spend.", tag = 3 },
        { "character_general_lust", "So let me give, for once -- the one thing this house took from you and never gave back.", tag = 4 },
        { "character_general_lust", "I keep every name that was traded for the cloth. Yours among them: the child you were, before they wrote a virtue over her and worked her to the bone inside it. Kneel, and it is yours again.", tag = 5 },
        { "character_amana", "...", tag = 6 },
        { "character_amana", "That name is not yours to give. Taking it back from your hand would only be one more theft.", tag = 7 },
        { "character_amana", "I know what I am called. I gave it to myself. And that, I am keeping.", tag = 8 },
    },
}
