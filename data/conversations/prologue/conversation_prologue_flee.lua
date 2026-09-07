-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Sworn over the ash of Bellmere, and the scene the Bastion line is built on. Rowan arrived at this
-- holding carrying an ASSIGNMENT -- the Order posted her to the baron and the baron's child was the
-- duty -- and this scene takes it away. Nothing stands over her for the first time in fifteen years,
-- and "We go on" is the first thing she has ever said uncommanded.
--
-- IT USED TO BE "WE SHALL HOLD", AND THE RIFT KILLED THAT. You cannot hold ground against a hole that
-- is still open behind you, and the scene says so two lines later. The Bastion's own sentence is still
-- *hold* (data/items/ability/ability_closed_ring.lua, carved over the cells) -- which now cuts the
-- right way round: the Order's word is hold, and the first thing she says without them is not.
--
-- THE LOAD IS ON THE "WE", not on the verb, and that is unchanged (docs/story.md, "Her oath"). She does
-- not promise to protect the player; she promises they are not doing it alone. The flaw is inside it
-- and must stay: she says it AT the avatar, nobody is asked, because she has treated a duty roster as a
-- bond for fifteen years. data/traits/trait_oathward.lua is the mechanical tell -- it guards whatever
-- ally is adjacent, undiscriminating, because oath one was never really about *you*.
--
-- SHE ISSUES IT TO HERSELF ("so I am giving myself one"), which is the same seam said out loud: the
-- only shape a promise can take, for her, is an order. She does not ANNOUNCE the vow first -- an
-- earlier draft had her say she was about to say something, which telegraphs the line and buys nothing.
--
-- SHE SENT THEM TO THE WEST ROAD -- her own order in the opening scene -- and this is where the player
-- learns it was a death sentence. The avatar tries to absolve her; she refuses. That is what makes the
-- vow something she does INSTEAD of grieving.
--
-- "[Rowan has joined your Party]" lands at the end of this scene (Conversation.drainJoins; see the
-- comment in states/prologue.lua for why it survives the fight in between).
return {
    title = "Ashes",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_avatar", "I can still see the hall from here.", tag = 1 },
        { "character_rowan", "There's nobody left to bring out, {name}. Your father. Bryn.", tag = 2 },
        { "character_rowan", "I sent them to the west road. It was already cut off.", tag = 11 },
        { "character_avatar", "You were told to keep me alive. You kept me alive.", tag = 4 },
        { "character_rowan", "My orders were one line. Keep the baron's child alive. That's all I did tonight.", tag = 5 },
        { "character_rowan", "The man who wrote them is dead. There's nobody left to give me another.", tag = 6 },
        { "character_rowan", "So I'm giving myself one. We go on.", tag = 8 },
        { "character_avatar", "Go on where? The field is still open.", tag = 9 },
        { "character_rowan", "Away from it, and not alone. The capital, {name}. Tonight.", tag = 10 },
    },
}
