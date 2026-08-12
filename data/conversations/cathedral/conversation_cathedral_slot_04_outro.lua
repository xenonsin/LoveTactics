-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The `outro` of data/quests/cathedral/quest_cathedral_slot_04.lua, and THE LINE'S FIRST REVEAL. Most
-- of this scene was written as Amana's recruit plea at slot 2, where she was a stranger the player had
-- just beaten and everything she said had to be taken on trust. Her recruit moved to the Colosseum's
-- padded card (docs/story.md, "The Cathedral"), so the plea moved here, which is where the sight is:
-- the party has just cleared a village of "corruption from the wild" and the corruption was children.
-- She is not asking to be believed now. She is naming what is already on the ground.
--
-- What she gave the party at the revival was the BOOK: the intake register, the words ascended to the
-- Light, the pit behind the almshouse (data/conversations/colosseum/conversation_colosseum_slot_02_join.lua).
-- She stopped there and said so. This is the rest of it, and the order matters: the player learned the
-- lie first and only now learns what it covers.
--
-- WHAT SHE CANNOT SAY, and this is the constraint that shapes every line here: **Amana does not know
-- the Saint is the demon.** That fact is slot 7, "the one fact Amana cannot yet face". So she blames a
-- rite and the small circle that keeps it, and she still believes in the Saint. She reaches for her as
-- the authority who would stop this if she only knew. The player is told enough to be horrified and
-- not enough to be right, and everything Amana says about the Saint here is sincere and wrong. Do not
-- let her sound suspicious of the altar; the drop at slot 7 is paid for by her faith holding now.
--
-- Her second cost stays in the subtext: taken as a child and renamed for a virtue, taught to want
-- nothing for herself. The one thing she keeps is the finale's, not this scene's.
--
-- The companion blocks are the standing rule (docs/story.md, "Every scene makes room for the party you
-- actually have"). Two of them land harder than the rest and are written to: Kaya has been paid for
-- this work and thanked for it, and Saber knows the shape of a house that takes children from the
-- outside, having come up on the sand alongside the Perennial, which does exactly this, and never once
-- been taken herself. Three of the seven institutions in this game are taking children. Nobody says
-- that sentence out loud; the party just keeps recognising it.
return {
    title = "The Purge in the Fold",
    cast  = { "character_amana", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } }, { id = "character_saber", when = { has = "character_saber" } }, { id = "character_gyeom", when = { has = "character_gyeom" } }, { id = "character_kaya", when = { has = "character_kaya" } }, { id = "character_ren", when = { has = "character_ren" } }, { id = "character_clem", when = { has = "character_clem" } } },

    script = {
        { "character_avatar", "The fold is clear. That is what the Cathedral hired us for.", tag = 1 },
        { "character_amana", "Do not put your sword away yet. Look at them first. Properly, all of them.", tag = 2 },
        { "character_avatar", "They are small.", tag = 3 },
        { "character_amana", "Yes.", tag = 4 },
        { "character_amana", "I have been carrying this since the night I brought you back, and I told you there were older names in the book. Sit down. I will give you the rest of it.", tag = 5 },
        { "character_amana", "The children the faith takes in are sorted. Most are made anointed. The holy warriors you have cheered in the street. A few of us are kept back as clergy, and never blooded.", tag = 6 },
        { "character_amana", "Blooded. That is the word for it. There is a rite, and the rite puts something into a child, and what it puts in is not the Light.", tag = 7 },
        { "character_amana", "It is demon's blood.", tag = 8 },
        { "character_avatar", "...You are certain.", tag = 9 },
        { "character_amana", "I stood close enough to be certain. Three things happen at that altar.", tag = 10 },
        { "character_amana", "It takes, and you get a soldier who will die gladly and never know what is in him. It takes wrong, and you get a thing that is hunted afterwards, and called a demon out of the wild.", tag = 11 },
        { "character_amana", "Those. On the ground. In front of you. Every one of them was a child in that hall a season ago.", tag = 12 },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "I have put down three of those this year and been thanked for it.", tag = 13 },
        } },
        { "character_amana", "And it kills. Most often, it simply kills. The body goes out the back and into the pit I showed you, and the register writes the child down as ascended to the Light.", tag = 14 },
        { "character_amana", "The roll of our glorious dead is a casualty list. Everyone reads it aloud on the feast day. Nobody has ever once counted it.", tag = 15 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "You knew this on the night you raised us. You held it a month.", tag = 16 },
            { "character_amana", "I held it until you could see it. Words would not have done this, and I would not have been believed.", tag = 17 },
            { "character_rowan", "You are believed. Go on.", tag = 18 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "How old are they when they take them?", tag = 19 },
            { "character_amana", "Six. Seven. Young enough not to remember being asked, because they were not.", tag = 20 },
            { "character_saber", "Mm. Then I know the shape of your house, priest, and I have never set foot in it.", tag = 21 },
        } },
        { "character_amana", "I hid nine of them, before any of you knew me. I would have hidden ninety. That is the whole of my crime and I will not pretend to regret it in front of you.", tag = 22 },
        { "character_avatar", "Then why has nobody in that building said a word?", tag = 23 },
        { "character_amana", "Because almost nobody in that building knows. That is what I need you to understand, and it is the part that sounds like an excuse.", tag = 24 },
        { "character_amana", "The faith is real. The people in it are good. I have knelt beside them my whole life. It is a small circle around the rite, and they have kept it from the rest of us for a generation.", tag = 25 },
        { "character_amana", "If the Saint herself were told, plainly, with proof she could not put aside. It would end that afternoon. I believe that. I have to; it is the last thing I have that is not on fire.", tag = 26 },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "That is a great deal of weight on one woman's ignorance.", tag = 27 },
            { "character_amana", "Yes. It is.", tag = 28 },
        } },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "A rite that kills most of the ones it is done to is not a rite. It is a yield. Somebody is running it as a yield.", tag = 29 },
            { "character_amana", "...I have not let myself put it that way.", tag = 30 },
        } },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "Somebody keeps that register. Ledgers don't write themselves, and the hand that keeps one always knows what it's for.", tag = 31 },
        } },
        { "character_avatar", "Then we go and read it ourselves.", tag = 32 },
        { "character_amana", "You will not be let near it, and I cannot walk back in to fetch it. I am fallen, and the word is theirs to give, and they gave it the day I did not come home.", tag = 33 },
        { "character_amana", "But you were never the faith's hand. You were hired by it and you are still standing here counting bodies, which makes you the only outfit in this country I could have said any of this to.", tag = 34 },
        { "character_amana", "Take me to that room. I only want to be standing somewhere the truth can still be carried.", tag = 35 },
    },
}
