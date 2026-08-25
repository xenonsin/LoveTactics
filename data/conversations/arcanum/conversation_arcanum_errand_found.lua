-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- TEMP PROSE. Placeholder, written to make the beat fire and to be replaced wholesale by the story
-- pass -- short on purpose. What it has to establish is only the shape: Gyeom is standing at arcanum's
-- posting, Gyeom asks the company to run it, and finishing it opens that house's door. The join
-- itself happens later, at the counter (models/vendor_visit.lua's joinCompanion).
--
-- Found by models/errand.lua's Errand.postingScene, which prefers a house's own
-- `conversation_<vendor>_errand_found` over the generic one. `{house}` and `{posting}` are set for
-- the scene's duration (states/game.lua's askErrand).
return {
    title = "A Posting Nobody Took",
    cast  = { "character_avatar", "character_gyeom" },

    script = {
        { "character_gyeom", "You are the first down here in a long while. This is {house}'s work, and it has been lying here.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { "character_gyeom", "I cannot finish it alone. Do it, and they will open their door to you. Ask for me there.", tag = 3 },
        { "character_avatar", "We take the work, or we leave it lying where it is. Choose...", tag = 4, choices = {
            { "Take the work.", tag = 5, answer = "accept" },
            { "Leave it lying.", tag = 6, answer = "decline" },
        } },
    },
}
