-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE RIFT COPIES PLACES. That is the premise every companion meeting now stands on: the floors throw
-- up pieces of the world above, wrong and out of order, and each of the six is standing at one of them
-- because the thing she came for is in it. No house posted this, no counter sent anybody, and nobody
-- is met in the city. The meeting happens underground, on the floor, mid-run (models/errand.lua).
--
-- CLEM, MET AT A VAULT DOOR THE RIFT HAS COPIED, the Bank's own mark still on it and a keeper behind it
-- who is still counting.
--
-- WHAT THIS SCENE HAS TO ESTABLISH: she was the Bank's finest blade and she turned the craft around. She
-- cancels debt now, burns notes, spirits the ruined away (data/characters/character_clem.lua). So she
-- splits the room before anyone opens it: the gold is yours, the ledgers are hers, and the ledgers are
-- going in a fire. That division IS the character.
return {
    title = "The Vault Door",
    cast  = { "character_avatar", "character_clem", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_clem", "You are loud. Be loud further back for a moment.", tag = 30 },
        { "character_clem", "There is a vault door on this floor with the Bank's mark on it, and a man behind it who counts footsteps for a living.", tag = 31 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "She knows the mark and she knows the man, {name}. She has been inside one of these.", tag = 32 },
        } },
        { "character_clem", "So let us be clear before it is open. The gold is yours. All of it. I will not touch a coin.", tag = 33 },
        { "character_clem", "What I want is the ledgers, and the ledgers are going in a fire.", tag = 34, choices = {
            { "Open it.", tag = 35, answer = "accept" },
            { "Walk away.", tag = 36, answer = "decline" },
        } },
    },
}
