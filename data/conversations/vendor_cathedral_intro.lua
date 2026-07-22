-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Arm Those Who Purge",
    cast  = { "cathedral", "character_avatar", { id = "character_amana", when = { has = "character_amana" } } },

    script = {
        { "cathedral", "You come armed and you come clean. The faithful arm those who purge -- wards, relics, water that burns what should not walk. Kneel when you take them, and the taking is made holy.", tag = 1 },
        { "character_avatar", "I'll take them standing.", tag = 2 },
        { when = { has = "character_amana" }, script = {
            { "character_amana", "Give what is offered and no more, quartermaster. {name} came for a censer, not a catechism.", tag = 3 },
            { "cathedral", "Sister. The cloth suits you still, whatever you tell the road.", tag = 4 },
            { "character_amana", "It was never offered to me either -- it was put on me. I wear what I choose to now. Arm us, and keep the sermon.", tag = 5 },
        } },
        { "cathedral", "...As you will. The shelf is open. The faith asks only that its gifts be used as it intended them -- and it always knows when they are not.", tag = 6 },
    },
}
