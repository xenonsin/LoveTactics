-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The stair guardian of the Greed circle, played over the fight. See
-- conversation_descent_gluttony.lua for what this folder is and why every scene in it is one speaker.
--
-- Aurea was a ruined debtor and pacted never to owe again. She is owed by everything and can keep,
-- feel or spend none of it, which is Midas exactly. Her rule takes the THING -- your kit, turned to
-- gold, mid-fight (data/items/utility/utility_bottomless_purse.lua) -- so the last line is a statement
-- of fact about the fight the player is walking into rather than a threat.

return {
    title = "Aurea, the Ever-Owed",
    cast  = { "character_general_greed" },

    script = {
        { "character_general_greed", "You came down here to be paid. Everyone who walks past me is on their way to being paid.", tag = 1 },
        { "character_general_greed", "I am owed by everything that lives. I have never once spent any of it and I have never once been able to stop collecting.", tag = 2 },
        { "character_general_greed", "What you are carrying is already mine. Bring it here.", tag = 3 },
    },
}
