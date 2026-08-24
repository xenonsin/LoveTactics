-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 3 OF 10 (docs/temptation.md), and the last of the worldly three. Still no voice in it: a
-- sergeant on a post with four days of wards left, who would rather they went somewhere they could do
-- something. Taking them is not even obviously wrong. That is the point -- the line spends three
-- quests establishing that saying yes is ordinary, so that slot 4 can say the identical sentence in a
-- mouth that is not a man's and the player has no clean place to draw the line behind them.
return {
    title = "The Weather",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "The sergeant asked me when the relief was due. I told him I didn't know.", tag = 1 },
        { "character_rowan", "He said that was fine.", tag = 2 },
        { "character_rowan", "He said it the way you'd say the weather was fine, {name}. Not bravely. It had just stopped being a question a long time ago.", tag = 3 },
        { "character_rowan", "There is nothing behind that post. There has not been for twenty years. They know it better than the archive does. They can see the empty fields from the wall.", tag = 4 },
        { "character_rowan", "It is what we teach. It is what I would have done.", tag = 5 },
        { "character_rowan", "He put his warding stores in front of me before we left. All of it. Four days' worth.", tag = 7 },
        { "character_rowan", "He said it does more good on a road than on a wall nobody is coming to.", tag = 8 },
        { "character_avatar", "...", tag = 9, choices = {
            { "\"He needs it more than we do.\"", tag = 10, goto = "refuse" },
            { "\"Take it. He's right.\"", tag = 11, goto = "took", effect = { grant = { "consumable_healing_potion", "consumable_healing_potion" }, gold = 60 } },
            { "\"Rowan. You tell him. He'll believe a knight.\"", tag = 12, goto = "with", effect = { grant = { "consumable_healing_potion", "consumable_healing_potion" }, gold = 60 } },
        } },
        { "character_rowan", "Then he keeps it. Four days is four days.", tag = 13, id = "refuse", goto = "after" },
        { "character_rowan", "He is right. I hate that he is right.", tag = 14, id = "took", goto = "after" },
        { "character_rowan", "...He handed it over the moment I asked.", tag = 15, id = "with" },
        { "character_rowan", "He would not have, for you. I want you to know that.", tag = 16 },
        { "character_rowan", "I have never watched it from outside before, and I do not know what I watched.", tag = 6, id = "after" },
    },
}
