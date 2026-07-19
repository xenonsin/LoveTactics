-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Rowan's Lesson",
    cast  = { "character_knight" },

    script = {
        { "character_knight", "Like that. Now yours, {name} -- close the ground and put it down.", tag = 1, id = "strike" },
        { "character_knight", "More of them, and they will not come near enough for a blade. Use your techniques. Get in among those two, where both can reach you.", tag = 2, id = "advance" },
        { "character_knight", "Now take it in hand.", tag = 3, id = "ready" },
        { "character_knight", "Turn on your heel, {name}. Open them both at once.", tag = 4, id = "clear" },
        { "character_knight", "That one is bigger. Take this too -- I never had the knack for it, and you may. It draws on something you have far less of than breath, so you get one.", tag = 5, id = "spark" },
        { "character_knight", "Let it have the spark. It will not know which way it is facing.", tag = 6, id = "jolt" },
        { "character_knight", "There -- it is reeling, and you are not. That is what the spark bought you: a turn it does not get. Finish it, {name}.", tag = 7, id = "finish" },
        { "character_knight", "Not that, {name}. Do as I showed you.", tag = 8, id = "nudge" },
        { "character_knight", "{select} on the imp to move in range and attack with your weapon.", tag = 9, id = "strike_hint" },
        { "character_knight", "{select} on the lit tile to move there.", tag = 10, id = "advance_hint" },
        { "character_knight", "{select} on Clear Out in your grid to ready it.", tag = 11, id = "ready_hint" },
        { "character_knight", "{select} on your own tile to spin.", tag = 12, id = "clear_hint" },
        { "character_knight", "{select} on Jolt to ready it. Its cost is purple: that is mana, not stamina.", tag = 13, id = "spark_hint" },
        { "character_knight", "{select} on the grunt to jolt it.", tag = 14, id = "jolt_hint" },
        { "character_knight", "{select} on the grunt to strike it -- its card slid down the order, so you act before it does.", tag = 15, id = "finish_hint" },
    },
}
