-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The opening of data/quests/the_gate_below.lua, played over the objective battle -- which is the only
-- seam the Crown can speak from at all. `intro` runs over the hub before the party is picked, and by
-- the time `outro` runs the target of an `assassinate` objective is already dead. See states/game.lua.
--
-- The scene has one job, and it is the thing the whole game has been arranging: the Crown has nothing
-- of its own to say. It had seven appetites, they were seven people, and the player has spent the
-- campaign taking them off it one at a time. So it speaks in THEIR voices -- quoting the dead back at
-- the party, because borrowed is the only register it has. That is the same claim its blueprint makes
-- in stats (an enormous pool and almost nothing behind it) and its trait makes in mechanics
-- (data/traits/trait_hollow_crown.lua wears three of the dead as its health falls). Three statements
-- of one idea, in three different languages.
--
-- The companion blocks are the standing rule (docs/story.md, "Every scene makes room for the party you
-- actually have"): each recruited companion answers the voice that belonged to THEIR line, so the
-- roster the player brought decides which of the dead get answered.
return {
    title = "The Hollow Crown",
    cast  = { "character_demon_lord", "character_avatar", { id = "character_knight", when = { has = "character_knight" } }, { id = "character_saber", when = { has = "character_saber" } }, { id = "character_amana", when = { has = "character_amana" } }, { id = "character_gyeom", when = { has = "character_gyeom" } }, { id = "character_kaya", when = { has = "character_kaya" } }, { id = "character_ren", when = { has = "character_ren" } }, { id = "character_clem", when = { has = "character_clem" } } },

    script = {
        { "character_demon_lord", "You came a long way down to meet me, and there is no me to meet.", tag = 1 },
        { "character_demon_lord", "Seven appetites. That was the whole of it. Seven wants, and seven people who agreed to carry one each, because a want cannot walk about on its own.", tag = 2 },
        { "character_demon_lord", "You took them off me one at a time. Careful work. I felt every one go the way you feel a tooth go -- not pain. An absence, with an edge on it.", tag = 3 },
        { "character_avatar", "Then there is nothing left of you.", tag = 4 },
        { "character_demon_lord", "Nothing is not the same as harmless.", tag = 5 },
        { "character_demon_lord", "I kept nothing of their souls. Souls are not food, and I was never sentimental. What I keep is the SHAPE a person makes when they say yes.", tag = 6 },
        { when = { has = "character_saber" }, script = {
            { "character_demon_lord", "Come and be measured, little card-filler. You were always going to lose to somebody the house had already paid.", tag = 7 },
            { "character_saber", "That is her mouth and it is not her. She never once said a thing she had been paid to say -- that was the whole trouble with her.", tag = 8 },
        } },
        { when = { has = "character_knight" }, script = {
            { "character_demon_lord", "Hold until relieved. Nobody is coming, girl. Nobody was ever coming.", tag = 9 },
            { "character_knight", "I know. I stopped waiting. You are forty-one days too late to frighten me with it.", tag = 10 },
        } },
        { when = { has = "character_gyeom" }, script = {
            { "character_demon_lord", "There is nothing in you I have not already surpassed.", tag = 11 },
            { "character_gyeom", "You are reciting. She meant it -- that was what was wrong with her. You are just holding the sound.", tag = 12 },
        } },
        { when = { has = "character_amana" }, script = {
            { "character_demon_lord", "Kneel, and I will give you back the name they took.", tag = 13 },
            { "character_amana", "I have a name. I gave it to myself, and you were not there.", tag = 14 },
        } },
        { when = { has = "character_kaya" }, script = {
            { "character_demon_lord", "The board never closes. There will be more in the spring. There are always more in the spring.", tag = 15 },
            { "character_kaya", "Then we will be there in the spring.", tag = 16 },
        } },
        { when = { has = "character_ren" }, script = {
            { "character_demon_lord", "Everything made can be unmade cheaper. Ask the girl who was poured.", tag = 17 },
            { "character_ren", "I did ask her. That is the difference between us, and it is not a small one.", tag = 18 },
        } },
        { when = { has = "character_clem" }, script = {
            { "character_demon_lord", "Everything is owed. Everything comes back to the house in the end.", tag = 19 },
            { "character_clem", "Not this. This one I am writing off.", tag = 20 },
        } },
        { "character_demon_lord", "You see? I still have all of them. And I can put one back on whenever I care to.", tag = 21 },
        { "character_demon_lord", "So do it properly, if you are going to. Not the appetite this time.", tag = 22 },
        { "character_demon_lord", "The thing that was hungry.", tag = 23 },
        { "character_avatar", "That is what we came down for.", tag = 24 },
    },
}
