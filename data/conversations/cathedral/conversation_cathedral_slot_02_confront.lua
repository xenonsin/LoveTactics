-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- The opening of data/quests/fallen_confessor.lua: the Cathedral names its own accused, Amana answers.
-- Canon (docs/story.md, "The Cathedral"): Amana is a clergy CONFESSOR on the acolyte track -- never
-- blooded -- who hid children from the consecration rite. The church voice here is SINCERE and does not
-- know the rite's true horror; it truly believes she is a thief. Amana withholds the truth on purpose --
-- the full reveal is her post-battle plea (the recruit `outro`), not this opening.
return {
    title = "The Fallen Confessor",
    cast  = { "cathedral", "character_amana" },

    script = {
        { "cathedral", "The one before you wore our cloth. A Confessor, no less -- she knows the charge.", tag = 1 },
        { "cathedral", "She stole children promised to the Light and hid them from the rite. That is theft from the faith. Purge her, and be paid.", tag = 2 },
        { "character_amana", "Children. The faith did not ask them, and it did not ask me. It has never once asked.", tag = 3 },
        { "character_amana", "And now it sends a stranger to take me back. I understand. Take is the only verb they were ever taught.", tag = 4 },
        { "character_amana", "You have been told what I am. You have not been told what they are -- what waits for those children past that rite. Not yet.", tag = 5 },
        { "character_amana", "I will not step aside, and I will not strike first. Beat me, then -- and before you collect your coin, you will hear me out.", tag = 6 },
    },
}
