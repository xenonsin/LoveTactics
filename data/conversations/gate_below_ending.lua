-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The `outro` of data/quests/the_gate_below.lua: the last scene in the game. It plays over the frozen
-- final battle frame, and states/game.lua hands off to states/credits.lua when it ends rather than to
-- the hub -- the one quest in the game whose completion does not go home.
--
-- What it refuses to do is the point. There is no revelation under the crown, because the whole design
-- of the thing is that it is empty (its blueprint: an enormous pool and almost nothing behind it; its
-- trait: every threat in the fight is borrowed). A last-minute secret would be the one lie the
-- campaign has not told. So the party kills it and finds exactly what they were promised -- nothing --
-- and the scene is about what that leaves them holding.
--
-- The sum nobody does out loud, which is the Bastion's own trick (docs/story.md: "Nobody does the sum
-- for the player"): seven generals were seven people who said yes, and killing the appetite does not
-- unmake the agreeing. The party notices. The world above never will.
--
-- Every companion closes their own line here, guarded the standing way, so the ending is the ending of
-- whichever game the player actually played.
return {
    title = "What Was Under It",
    cast  = { "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } }, { id = "character_saber", when = { has = "character_saber" } }, { id = "character_amana", when = { has = "character_amana" } }, { id = "character_gyeom", when = { has = "character_gyeom" } }, { id = "character_kaya", when = { has = "character_kaya" } }, { id = "character_ren", when = { has = "character_ren" } }, { id = "character_clem", when = { has = "character_clem" } } },

    script = {
        { "character_avatar", "...", tag = 1 },
        { "character_avatar", "It is not leaving anything behind.", tag = 2 },
        { "character_avatar", "No shape on the floor. No last word. It emptied out like a coat coming off a hook.", tag = 3 },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "Because that is what it was. We kept expecting a thing wearing seven appetites. It was seven appetites wearing a thing.", tag = 4 },
            { "character_gyeom", "Take them off and you are not left with a monster. You are left with the hook.", tag = 5 },
        } },
        { when = { has = "character_amana" }, script = {
            { "character_amana", "Seven people said yes to it.", tag = 6 },
            { "character_amana", "That part does not come off. We killed the wanting. We did not un-ask the question, and it was asked of them, and every one of them answered.", tag = 7 },
        } },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Forty-one of mine answered it too, and they were not monsters when they did. They were cold, and tired, and somebody offered.", tag = 8 },
            { "character_rowan", "I have stopped being able to tell that story as though the ending was obvious.", tag = 9 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "There is a reckoning owed under this floor and it is paid. I have wanted that since before I had a name that was mine to give out.", tag = 10 },
            { "character_saber", "Nobody booked this one. Nobody wrote the ending. It came out how it came out, and it is ours.", tag = 11 },
        } },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "Listen to it. That is the quietest a wood has been in my whole life, and I have spent my whole life making woods quiet.", tag = 12 },
            { "character_kaya", "I do not think I have to any more.", tag = 13 },
        } },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "You are all standing. I want to say that out loud, because I spent the entire way down assuming I would be counting.", tag = 14 },
            { "character_ren", "Somebody put a hand under me on the stair, and I let them. That is new. I am keeping it.", tag = 15 },
        } },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "Everything is owed, it said. Everything comes back to the house.", tag = 16 },
            { "character_clem", "The house is a hole in the ground and I am walking out of it. Let it stay owed.", tag = 17 },
            { "character_clem", "...including mine. Fine. Especially mine.", tag = 18 },
        } },
        { "character_avatar", "Nobody up there is going to know what this was.", tag = 19 },
        { "character_avatar", "The board will post work in the morning. The shops will open. Somebody will complain about the price of steel.", tag = 20 },
        { "character_avatar", "That is the whole of what we were for. That it stays boring up there.", tag = 21 },
        { "character_avatar", "Come on. It is a long stair and I would like to see the sky do the thing it does.", tag = 22 },
    },
}
