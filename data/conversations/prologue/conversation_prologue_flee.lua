-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Sworn over the ash of Bellmere, and the scene the Bastion line is built on. Rowan arrives here
-- carrying an ASSIGNMENT: the Order posted her to the baron's holding and the baron's child was the
-- duty. That is the thing this scene takes away from her. The baron is dead, the house is ash, the
-- contract that put her at this gate no longer has anyone standing behind it -- so for the first time
-- in fifteen years she has no orders, and "We shall hold" is the first thing she has ever said
-- uncommanded.
--
-- The flaw is inside it and must stay there: she says it AT the avatar, not to them. Nobody is asked.
-- She was handed a duty roster and turned it into a vow without ever checking whether the difference
-- mattered, which is the Order's own sin answered the other way round (docs/story.md, "The Bastion").
-- data/traits/trait_oathward.lua is the mechanical tell -- it guards whatever ally happens to be
-- adjacent, unconditionally, because oath one was never really about *you*.
--
-- "[Rowan has joined your Party]" lands at the end of this scene (Conversation.drainJoins; see the
-- comment in states/prologue.lua for why it survives the fight in between).
return {
    title = "Ashes",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_avatar", "I can still see the hall from here. All of it is still burning.", tag = 1 },
        { "character_rowan", "I went back through the east quarter, {name}. There is nobody left to bring out.", tag = 2 },
        { "character_rowan", "Your father. Ellis. Odo at the bell, where you would expect him. I could not reach that side of the town in time.", tag = 11 },
        { "character_avatar", "You were told to keep me alive. You kept me alive.", tag = 4 },
        { "character_rowan", "I was charged with the body of a baron's child, and that is the whole of what I did tonight.", tag = 5 },
        { "character_rowan", "The man who charged me is dead. The house that paid the Order is ash. There is nothing standing over me now.", tag = 6 },
        { "character_rowan", "So I will say one of my own. It is two words.", tag = 7 },
        { "character_rowan", "We shall hold.", tag = 8 },
        { "character_avatar", "Hold what? There is nothing here left to hold.", tag = 9 },
        { "character_rowan", "Not this ground. It was never the ground. We go to the capital while its walls are still standing.", tag = 10 },
    },
}
