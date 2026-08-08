-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Too Clean",
    cast  = { "bastion", "character_rowan" },

    script = {
        { "bastion", "A crew on the eastern road. Six wagons in a season, no lives taken, nothing burned.", tag = 1 },
        { "character_rowan", "That is not a crew, that is a garrison. Who are they?", tag = 2 },
        { "bastion", "Road-men.", tag = 3 },
        { "character_rowan", "Road-men leave bodies.", tag = 4 },
        { "bastion", "These are to be ended, Squire. Not brought in. Ended.", tag = 5, choices = {
            { "\"You know who they are, don't you.\"", tag = 6, goto = "press" },
            { "\"Six wagons. That's it?\"", tag = 7, goto = "wagons" },
        } },
        { "bastion", "I know what the contract says. So do you.", tag = 8, id = "press", goto = "ready" },
        { "bastion", "Six that were reported. Take the work or leave it on the board.", tag = 9, id = "wagons" },
        { "character_rowan", "...As you say.", tag = 10, id = "ready" },
        { "character_rowan", "{name}. A word before we go.", tag = 11 },
        { "character_rowan", "Every quarter I have served, the order has wanted men like that alive and talking.", tag = 12 },
        { "character_rowan", "You bring a deserter in. You read him the list. He goes back on the line where he is some use.", tag = 15 },
        { "character_rowan", "I have never once been told to end one.", tag = 13 },
        { "character_rowan", "It will be in the reports somewhere and I will find it when we're back. Come on.", tag = 14 },
    },
}
