-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Rowan's Lesson",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "Close the distance and strike without fear, {name}!", tag = 1, id = "strike" },
        { "character_rowan", "There's more to the north. Slay them both before they do even more damage.", tag = 2, id = "advance" },
        { "character_rowan", "Now take it in hand.", tag = 3, id = "ready" },
        { "character_rowan", "Turn on your heel, {name}. Open them both at once.", tag = 4, id = "clear" },
        { "character_rowan", "That big one is about to strike, use your magic, {name}!", tag = 5, id = "spark" },
        { "character_rowan", "Let it have the spark. It will not know which way it is facing.", tag = 6, id = "jolt" },
        { "character_rowan", "While it's stunned, {name}. Let's finish this!", tag = 7, id = "finish" },
        { "character_rowan", "Not that, {name}. Do as I showed you.", tag = 8, id = "nudge" },
        { "character_rowan", "{select} on the imp to move in range and attack with your weapon.", tag = 9, id = "strike_hint" },
        { "character_rowan", "{select} on the lit tile to move there.", tag = 10, id = "advance_hint" },
        { "character_rowan", "{select} on Clear Out in your grid to ready it.", tag = 11, id = "ready_hint" },
        { "character_rowan", "{select} on your own tile to spin.", tag = 12, id = "clear_hint" },
        { "character_rowan", "{select} on Jolt to ready it. Its cost is purple: that is mana, not stamina.", tag = 13, id = "spark_hint" },
        { "character_rowan", "{select} on the grunt to jolt it.", tag = 14, id = "jolt_hint" },
        { "character_rowan", "{select} on the grunt to strike it -- its card slid down the order, so you act before it does.", tag = 15, id = "finish_hint" },
    },
}
