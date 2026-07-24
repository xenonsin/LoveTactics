-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Shelf Is Yours",
    cast  = { "bastion", "character_avatar", { id = "character_knight", when = { has = "character_knight" } } },

    script = {
        { "bastion", "You have earned the {discipline} road, {name}. The quartermaster has moved its gear onto your rack -- kit the Watch keeps for the ones who prove they can carry it.", tag = 1 },
        { "character_avatar", "Then it's earned. Show me.", tag = 2 },
        { when = { has = "character_knight" }, script = {
            { "character_knight", "I trained beside a few who took that road. It is a good one. Do not let the rack outgrow the arm.", tag = 3 },
        } },
    },
}
