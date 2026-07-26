-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Rowan's Lesson",
    cast  = { "character_knight" },

    script = {
        { "character_knight", "Close the distance and strike without fear, {name}!", tag = 1, id = "strike" },
        { "character_knight", "There's more to the north. Slay them both before they do even more damage.", tag = 2, id = "advance" },
        { "character_knight", "Now take it in hand.", tag = 3, id = "ready" },
        { "character_knight", "Turn on your heel, {name}. Open them both at once.", tag = 4, id = "clear" },
        { "character_knight", "That big one is about to strike, use your magic, {name}!", tag = 5, id = "spark" },
        { "character_knight", "Let it have the spark. It will not know which way it is facing.", tag = 6, id = "jolt" },
        { "character_knight", "While it's stunned, {name}. Let's finish this!", tag = 7, id = "finish" },
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
