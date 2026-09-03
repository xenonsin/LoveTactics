-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- A POSTING FROM A HOUSE THAT HAS NO DOOR YET. This is the one piece of work in the game nobody ever
-- asked the company for: it is lying on a descent floor at its own dead end, and finishing it is what
-- opens that house's shop (models/errand.lua's Errand.opener). Until this scene existed the company
-- walked into it, fought it, and learned what it had been for from a shelf that moved a day later.
--
-- Speaks for all seven houses: `{house}` is the name and `{posting}` is the quest's own description,
-- both set on the player for the scene's duration (states/game.lua's askErrand).
return {
    title = "A Posting Nobody Took",
    cast  = { "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_avatar", "There is a seal cut into the stone here, and it is not an old one. {house}, out of the city.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "They posted it and nobody came down for it. A house pays what it owes, {name}, and it opens its counter to whoever finishes the job. Their door is shut to us today.", tag = 3 },
        } },
        { "character_avatar", "We take the work, or we leave it lying where it is. Choose...", tag = 4, choices = {
            { "Take the work.", tag = 5, answer = "accept" },
            { "Leave it lying.", tag = 6, answer = "decline" },
        } },
    },
}
