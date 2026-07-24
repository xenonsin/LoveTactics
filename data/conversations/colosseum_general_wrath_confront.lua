-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The opening of data/quests/general_wrath.lua -- the Colosseum's slot 10, and the last of the seven
-- generals to get a voice. Played over the objective battle, the only seam an antagonist can speak
-- from (see states/game.lua).
--
-- The hard rules this scene is written against, all from docs/story.md, "The Colosseum":
--
--   * **She must never ask to die.** That would let Saber off the hook. Ira wants to keep feeling right
--     to the end, and Saber has to do it to her anyway. Nothing here may read as a request.
--   * **Never operatic.** The Perennial took children and made instruments; what got through to Ira
--     was one handler who broke protocol and talked to her, and the house answered with a REASSIGNMENT.
--     A form, not a murder. The register the scene speaks in is administrative, and that is the horror.
--   * **There is no one to be paid by.** No grave, no throat, no confession that settles it. She is not
--     chasing revenge -- rage is the only evidence ever placed in her hands that there is a person
--     inside the instrument, and being hit is the only way she gets it.
--   * **Blind from birth.** She reads the room by sound and by weight on the sand, never by sight, and
--     nothing in her dialogue may quietly assume otherwise.
--   * **Saber is recognition, not love.** They were never partners. Saber is looking at the version of
--     herself the process finished, and she is the only one present who understands that the thing
--     under the sand is a manufactured woman rather than a monster.
--
-- What the scene deliberately does NOT settle: whether Ira is the one general the "every general is a
-- human who pacted with the Demon Lord" rule spares, or whether the pact was struck on her behalf by
-- the house. docs/story.md says to leave that contradiction standing until it is resolved on purpose
-- and not to quietly rewrite her, so no line here claims she agreed to anything. She never chose; that
-- is the entire point of her, and it is left load-bearing and unexplained.
--
-- The one thing she is curious about is Saber putting her sword down in front of a paying house. Of
-- course it is: it is the only account she has ever heard of somebody else's feeling doing something.
return {
    title = "Ira, the Unappeased",
    cast  = { "character_general_wrath", "character_avatar", { id = "character_saber", when = { has = "character_saber" } }, { id = "character_knight", when = { has = "character_knight" } }, { id = "character_amana", when = { has = "character_amana" } }, { id = "character_gyeom", when = { has = "character_gyeom" } }, { id = "character_kaya", when = { has = "character_kaya" } }, { id = "character_ren", when = { has = "character_ren" } }, { id = "character_clem", when = { has = "character_clem" } } },

    script = {
        { "character_general_wrath", "You came down the stair together, and one of you is favouring a left foot. You have been fighting already.", tag = 1 },
        { "character_general_wrath", "Good. I was told this was scheduled for the ninth. They moved it and did not say so, which is usual.", tag = 2 },
        { "character_avatar", "Scheduled.", tag = 3 },
        { "character_general_wrath", "Everything I have done was scheduled. This is a card like any other card. You are on it.", tag = 4 },
        { when = { has = "character_saber" }, script = {
            { "character_general_wrath", "You are standing too still. Everyone shifts. You have been taught not to and you kept it.", tag = 5 },
            { "character_saber", "Ira.", tag = 6 },
            { "character_general_wrath", "That is the name, yes. You came out of the house.", tag = 7 },
            { "character_saber", "I washed out of it.", tag = 8 },
            { "character_general_wrath", "I know. They keep the ones who wash out in the ledger for a while, in case it takes late. Then they stop.", tag = 9 },
            { "character_general_wrath", "I do not remember you. I do not remember anyone. That is not unkindness, it is the specification.", tag = 10 },
        } },
        { "character_general_wrath", "I will tell you what I am, since you came all this way and will not otherwise believe it of a person.", tag = 11 },
        { "character_general_wrath", "I have no fear. No pain. Nothing holds to me -- they saw to all of it before I could walk, and they were thorough, and I was very good.", tag = 12 },
        { "character_general_wrath", "I felt nothing about being very good.", tag = 13 },
        { "character_general_wrath", "Then one year somebody assigned to me broke protocol and talked to me. Described the room. Described the crowd. Told me what colour things were, which meant nothing and I have never forgotten a word of it.", tag = 14 },
        { "character_general_wrath", "And I was angry when they were taken away. That was the first thing I ever felt. It arrived whole, and it was mine, and it has been the only proof I have ever had that there is anyone in here.", tag = 15 },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "Taken away where?", tag = 16 },
            { "character_general_wrath", "Reassigned. There is a form. I have never seen where the form goes.", tag = 17 },
            { "character_ren", "...Oh.", tag = 18 },
        } },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "So there's nobody to collect from. Not one name at the bottom of it.", tag = 19 },
            { "character_general_wrath", "No. I have looked. That is why it does not close.", tag = 20 },
        } },
        { when = { has = "character_amana" }, script = {
            { "character_amana", "How old were you when they began?", tag = 21 },
            { "character_general_wrath", "There was no beginning. There is no part of me from before it.", tag = 22 },
            { "character_amana", "...I know a house that does this. I did not know there were two.", tag = 23 },
        } },
        { when = { has = "character_knight" }, script = {
            { "character_knight", "And the stable never once said what it had made.", tag = 24 },
            { "character_general_wrath", "It cannot. Saying what I am means saying what the programme is, and the programme is still running. There are children in the intake tonight.", tag = 25 },
        } },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "You have described a life with one feeling in it and called that proof of a person. It is not much of a proof.", tag = 26 },
            { "character_general_wrath", "It is the only one I was issued.", tag = 27 },
        } },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "Nothing in a wood is built like you. Every animal out there can be frightened. That is what keeps it alive.", tag = 28 },
            { "character_general_wrath", "Yes. I have been told I am superb.", tag = 29 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_general_wrath", "Veteran. They say you put your sword down once, on a full house, and would not finish what you were told to finish.", tag = 30 },
            { "character_saber", "They died anyway. Somebody else did it while I stood there.", tag = 31 },
            { "character_general_wrath", "I have thought about that more than I have thought about anything.", tag = 32 },
            { "character_general_wrath", "Not whether it was right. I have no instrument for that. Only that a feeling went into you and a whole arena had to stop and wait for it. Mine has never moved anything at all.", tag = 33 },
            { "character_saber", "...Ira. I came down here believing I could take you out of it. That there was somewhere else you could be put.", tag = 34 },
            { "character_general_wrath", "I know what you are offering. I had it.", tag = 35 },
            { "character_general_wrath", "There was no one in it.", tag = 36 },
        } },
        { "character_general_wrath", "So. Come and hit me properly. Not fast -- fast is nothing, and I have had a great deal of nothing.", tag = 37 },
        { "character_general_wrath", "Every blow you land wakes a little more of me up. You will find that inconvenient. It is the only hour of my life I am ever present for, and I intend to be present for all of it.", tag = 38 },
        { "character_avatar", "That is not a reason to keep going.", tag = 39 },
        { "character_general_wrath", "It is the only one there is. Begin.", tag = 40 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "I do not kill people who cannot choose.", tag = 41 },
            { "character_saber", "...Guard yourselves. I am going to do it anyway, and I would rather nobody tells me later that it was mercy.", tag = 42 },
        } },
    },
}
