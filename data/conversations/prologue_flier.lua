-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Played the first time the player opens the Quest Board, after the arrival (states/hub.lua coaches
-- the board, then fires this before the panel opens). Rowan spots the Colosseum's flier and reads it
-- as the one contract a two-person company with no name can actually take -- which motivates the
-- debut (data/quests/arena_debut.lua), the only quest on the board at prestige 1. "So you do."
return {
    title = "The Board",
    cast  = { "character_knight", "character_avatar" },

    script = {
        { "character_avatar", "Bounties, escorts, standing contracts... half of these want a company three times our size.", tag = 1 },
        { "character_knight", "This one doesn't.", tag = 2 },
        { "character_knight", "The Colosseum. They pay for a debut bout -- a single fight, on the sand, in front of a crowd. Win or lose, the purse is posted the same.", tag = 3 },
        { "character_avatar", "A blood sport.", tag = 4 },
        { "character_knight", "A paying one, and it asks only two on the field. It is not the war we came to fight, {name}... but it is the coin we can earn today. Take it, and we eat.", tag = 5 },
    },
}
