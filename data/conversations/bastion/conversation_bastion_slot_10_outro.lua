-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- WHERE THE BASTION'S LEDGER IS PAID (docs/temptation.md). Acedia is dead either way; what this scene
-- says depends on what the player answered ten times on the way here. Quest.complete has already
-- resolved the line by the time this plays (`endsLine`), so exactly one of the three flags below is
-- set, and states/game.lua runs Temptation.settle AFTER this scene -- which is the only reason the
-- `left` branch can exist at all, because she has to still be on the roster to say goodbye in it.
--
-- ALL THREE ENDINGS ARE GATED POSITIVELY, never with `notFlag`. A negative condition is invisible in
-- tests/conversation_spec.lua's fully-unlocked context by construction and its lines would read as
-- unreachable; the note there explains the trade. The first three lines stay ungated as the shared
-- body, so a save that somehow arrives here with no outcome stamped still plays a scene rather than
-- nothing.
--
-- The HELD branch is the original scene, unchanged, down to its tags. That is deliberate: it is what
-- this line was always for, and the other two are what the player did instead of it.
return {
    title = "Until Relieved",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "She was smaller than the shield made her.", tag = 1 },
        { "character_rowan", "They will read her name at muster tomorrow. Nobody there will know. I am not going to be the one who tells them. Not this month.", tag = 2 },
        { "character_rowan", "Maybe the line empties. She may have been right about that. I will find out with everybody else.", tag = 3 },
        { when = { flag = "held_bastion" }, script = {
            { "character_rowan", "{name}.", tag = 4 },
            { "character_rowan", "Fifteen years the order taught me to hold until relieved. I never once noticed what that means. You wait for somebody else to decide you may stop.", tag = 5 },
            { "character_rowan", "I am not waiting to be relieved. I am not the relief either. I tried that, and it only meant running everywhere and arriving nowhere.", tag = 6 },
            { "character_rowan", "I am here, and it is you, and I picked it.", tag = 7 },
            { "character_rowan", "We shall hold.", tag = 8 },
        } },
        { when = { flag = "left_bastion" }, script = {
            { "character_rowan", "{name}.", tag = 9 },
            { "character_rowan", "I have been trying to find a way to say this that is fair to you and I do not think there is one, so I am going to say it badly.", tag = 10 },
            { "character_rowan", "I watched you decide, over and over, and every time I told myself it was the road and not the person.", tag = 11 },
            { "character_rowan", "She said no post is worth holding. You did not argue with her. You have not argued with her for a long time.", tag = 12 },
            { "character_avatar", "...", tag = 13, choices = {
                { "\"Rowan. Stay.\"", tag = 14, goto = "answered" },
                { "\"...\"", tag = 15, goto = "answered" },
            } },
            { "character_rowan", "I know. I believe you mean it.", tag = 16, id = "answered" },
            { "character_rowan", "I swore to you in the ash and I meant that too, and I am still going to be somewhere the day it costs something.", tag = 17 },
            { "character_rowan", "It is not going to be here.", tag = 18 },
            { "character_rowan", "Do not follow me down that road. I will not stop.", tag = 19 },
        } },
        { when = { flag = "caved_bastion" }, script = {
            { "character_rowan", "{name}. Come here. Sit down for a minute.", tag = 20 },
            { "character_rowan", "I have not felt like this since I was sixteen years old.", tag = 21 },
            { "character_rowan", "Fifteen years I have been carrying a full waterskin around asking people if they needed it, and nobody ever did, and I never once put it down.", tag = 22 },
            { "character_rowan", "You put it down for me. You did it so gently I did not notice you doing it.", tag = 23 },
            { "character_rowan", "The pike is hers. I am going to carry it. It is a good weapon and she has no further use for it.", tag = 24 },
            { "character_avatar", "...", tag = 25, choices = {
                { "\"You've earned it.\"", tag = 26, goto = "closed" },
                { "\"...\"", tag = 27, goto = "closed" },
            } },
            { "character_rowan", "There is nothing waiting for me at the muster tent and there never was.", tag = 28, id = "closed" },
            { "character_rowan", "Wherever you are going next, I am coming. Not because I swore anything.", tag = 29 },
            { "character_rowan", "Because I have got nothing else to do, and you are the only thing I like.", tag = 30 },
        } },
    },
}
