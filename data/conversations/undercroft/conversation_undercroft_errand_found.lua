-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- CLEM, MET AT THE UNDERCROFT'S POSTING. The first beat of a recruit (models/errand.lua): she asks at
-- the doorway, the vault is the ask, and clearing it recruits her.
--
-- WHAT THIS SCENE HAS TO ESTABLISH: she was the Bank's own finest blade and she turned the craft around
-- -- she cancels debt now, burns notes, spirits the ruined away (data/characters/character_clem.lua).
-- So she splits the room before anyone opens it: the gold is yours, the ledgers are hers, and the
-- ledgers are going in a fire. That division IS the character, and it is the one thing the Undercroft's
-- posting would never say out loud.
return {
    title = "The Vault Door",
    cast  = { "character_avatar", "character_clem", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_clem", "You are loud. Be loud further back for a moment -- there is a man behind that door who counts footsteps for a living and he is very good at it.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { "character_clem", "Two keys, three doors, and the Undercroft would prefer you did not sit down and do that sum. The third door is the keeper. He does not open politely for me and he will not open politely for you.", tag = 3 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "She knows the count of the doors and the name of the man. She has been inside, {name}.", tag = 4 },
        } },
        { "character_clem", "So let us be clear before it is open, because after is too late to be clear. The gold is yours -- all of it, I will not touch a coin. What I want is the ledgers, and the ledgers are going in a fire, and everyone whose name is in them stops owing tonight.", tag = 5 },
        { "character_avatar", "We open it on that understanding, or we walk away from the door. Choose...", tag = 6, choices = {
            { "Open it.", tag = 7, answer = "accept" },
            { "Walk away.", tag = 8, answer = "decline" },
        } },
    },
}
