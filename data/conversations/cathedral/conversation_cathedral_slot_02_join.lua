-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The `outro` of data/quests/fallen_confessor.lua -- the Cathedral's slot 2, and the scene the line's
-- ten-slot table calls "bested, Amana stays your hand and her plea reveals the truth; she joins"
-- (docs/story.md, "The Cathedral"). Player.recruit has already added her by the time this runs, so the
-- join banner rides the scene (Conversation.drainJoins).
--
-- The plea is the payload: the "holy" magic that makes an anointed is demonic blood; the rite kills
-- many of the children it is done to; the ones it takes WRONG become the ferals the church hunts as
-- "demons from the wild" -- which is the work the player has been hired for; and the dead are written
-- into the intake register as *ascended to the Light* and tipped into an unmarked pit.
--
-- WHAT SHE CANNOT SAY, and this is the constraint that shapes every line here: **Amana does not know
-- the Saint is the demon.** That fact is slot 7, "the one fact Amana cannot yet face". So she blames a
-- rite and the small circle that keeps it, and she still believes in the Saint -- she reaches for her
-- as the authority who would stop this if she only knew. The player is told enough to be horrified and
-- not enough to be right, and everything Amana says about the Saint here is sincere and wrong. Do not
-- let her sound suspicious of the altar; the drop at slot 7 is paid for by her faith holding now.
--
-- Her second cost stays in the subtext: taken as a child and renamed for a virtue, taught to want
-- nothing for herself. So she asks for nothing -- she offers. The one thing she keeps is the finale's
-- (data/conversations/cathedral_general_lust_confront.lua), not this scene's.
--
-- The companion blocks are the standing rule (docs/story.md, "Every scene makes room for the party you
-- actually have"). Two of them land harder than the rest and are written to: Rowan's order writes its
-- own dead into a roll of martyrs by exactly this trick, and Saber knows the shape of a house that takes
-- children from the outside -- she came up on the sand alongside the Perennial, which does exactly this,
-- and was never once taken herself. Three of the seven institutions in this game are taking children.
-- Nobody says that sentence out loud; the party just keeps recognising it.
return {
    title = "A Trust Returned",
    cast  = { "character_amana", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } }, { id = "character_saber", when = { has = "character_saber" } }, { id = "character_gyeom", when = { has = "character_gyeom" } }, { id = "character_kaya", when = { has = "character_kaya" } }, { id = "character_ren", when = { has = "character_ren" } }, { id = "character_clem", when = { has = "character_clem" } } },

    script = {
        { "character_amana", "Enough. You have me. The coin is yours whatever happens next. I am not asking you to give that up.", tag = 1 },
        { "character_amana", "I am asking for the walk back. That is all. Hear it, and then take me in if you still mean to.", tag = 2 },
        { "character_avatar", "Say it.", tag = 3 },
        { "character_amana", "The children the faith takes in are sorted. Most are made anointed. The holy warriors you have cheered in the street. A few of us are kept back as clergy, and never blooded.", tag = 4 },
        { "character_amana", "Blooded. That is the word for it. There is a rite, and the rite puts something into a child, and what it puts in is not the Light.", tag = 5 },
        { "character_amana", "It is demon's blood.", tag = 6 },
        { "character_avatar", "...You are certain.", tag = 7 },
        { "character_amana", "I stood close enough to be certain. Three things happen at that altar.", tag = 8 },
        { "character_amana", "It takes, and you get a soldier who will die gladly and never know what is in him. It takes wrong, and you get a thing that is hunted afterwards, and called a demon out of the wild.", tag = 9 },
        { "character_amana", "Those. The corruption you are paid to purge. Every one of them was a child in that hall a season ago.", tag = 10 },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "I have put down three of those this year and been thanked for it.", tag = 11 },
        } },
        { "character_amana", "And it kills. Most often, it simply kills. The body goes out the back and into a pit with no marker on it, and the register writes the child down as ascended to the Light.", tag = 12 },
        { "character_amana", "The roll of our glorious dead is a casualty list. Everyone reads it aloud on the feast day. Nobody has ever once counted it.", tag = 13 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "...Say that last part again.", tag = 14 },
            { "character_amana", "The register writes them down as ascended.", tag = 15 },
            { "character_rowan", "My order carves a mark for each of its dead and teaches children the marks are days held. Same trick. Different stone.", tag = 16 },
            { "character_rowan", "I am sorry. Go on. I did not mean to make this mine.", tag = 17 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "How old are they when they take them?", tag = 18 },
            { "character_amana", "Six. Seven. Young enough not to remember being asked, because they were not.", tag = 19 },
            { "character_saber", "Mm. Then I know the shape of your house, priest, and I have never set foot in it.", tag = 20 },
        } },
        { "character_amana", "I hid nine of them. I would have hidden ninety. That is the whole of my crime and I will not pretend to regret it in front of you.", tag = 21 },
        { "character_avatar", "Then why is a Confessor standing in a wood alone? Why has nobody in that building said a word?", tag = 22 },
        { "character_amana", "Because almost nobody in that building knows. That is what I need you to understand, and it is the part that sounds like an excuse.", tag = 23 },
        { "character_amana", "The faith is real. The people in it are good. I have knelt beside them my whole life. It is a small circle around the rite, and they have kept it from the rest of us for a generation.", tag = 24 },
        { "character_amana", "If the Saint herself were told, plainly, with proof she could not put aside. It would end that afternoon. I believe that. I have to; it is the last thing I have that is not on fire.", tag = 25 },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "That is a great deal of weight on one woman's ignorance.", tag = 26 },
            { "character_amana", "Yes. It is.", tag = 27 },
        } },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "A rite that kills most of the ones it is done to is not a rite. It is a yield. Somebody is running it as a yield.", tag = 28 },
            { "character_amana", "...I have not let myself put it that way.", tag = 29 },
        } },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "Somebody keeps that register. Ledgers don't write themselves, and the hand that keeps one always knows what it's for.", tag = 30 },
        } },
        { "character_amana", "So. I cannot walk back in. I am fallen, and the word is theirs to give, and they have given it.", tag = 31 },
        { "character_amana", "But you are not the faith's hand. You were hired by it once and you did not finish the job, which makes you the only outfit in this country I can say any of this to.", tag = 32 },
        { "character_amana", "Take me with you. I will not ask you for a wage, or a share, or a say in where we go. I have never been much good at wanting things for myself. They were thorough about that.", tag = 33 },
        { "character_amana", "I only want to be standing somewhere the truth can still be carried. Let me carry it.", tag = 34 },
        { "character_avatar", "You can want a wage too. We'll start there.", tag = 35 },
        { "character_amana", "...I will think about it.", tag = 36 },
    },
}
