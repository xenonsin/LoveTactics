-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Nineteenth",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "Here. The relief order cut for Greywatch. Sealed, dated, countersigned by two hands.", tag = 1 },
        { "character_rowan", "Issued on the nineteenth.", tag = 2 },
        { "character_rowan", "The gate was opened on the fourteenth.", tag = 3 },
        { "character_rowan", "Five days, {name}. She opened it five days before anyone in this order was so much as ORDERED to come for her.", tag = 4 },
        { "character_rowan", "There was no relief. There was nothing to be late for.", tag = 5, choices = {
            { "\"Rowan. There was never anything you could have done.\"", tag = 6, goto = "absolve" },
            { "\"...\"", tag = 7, goto = "silent" },
        } },
        { "character_rowan", "Don't. Don't you hand me that.", tag = 8, id = "absolve", goto = "after" },
        { "character_rowan", "Say it. You want to say it. That I'm innocent, that I was sixteen, that the mule was not the problem.", tag = 9, id = "silent" },
        { "character_rowan", "I would rather have been late.", tag = 10, id = "after" },
        { "character_rowan", "Late is a thing a person can carry. Late means there was a door and I did not reach it in time, and a woman was on the other side of it holding.", tag = 11 },
        { "character_rowan", "Take that away and I am not someone who was late. I am someone who built herself, brick by brick, out of an apology to a person who never needed one.", tag = 12 },
        { "character_rowan", "So no. I'll keep the guilt, thank you.", tag = 13 },
        { "character_rowan", "And we are not finished. Somebody in this order cut that seal, and somebody has been reading her name aloud ever since.", tag = 14 },
    },
}
