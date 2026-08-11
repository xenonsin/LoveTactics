-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The first scene in the game. Its job is to spend twenty seconds in a house before burning it: the
-- player is the baron of Bellmere's child, and the people who die that night have to stand on screen
-- first or their deaths are a fact in a document rather than a loss.
--
-- ELLIS IS THE BODY THE PLAYER DID NOT CHOOSE. Character creation offers two and only one of them is
-- you; the other is your sibling, and it is the other one's face standing here. That costs no art
-- (the portrait is resolved in models/conversation.lua's `speaker`, beside the avatar's own override)
-- and it turns a menu choice made before the first line into something the player loses. Ellis is
-- addressed by name and never by relation -- a body is a sprite set and never a gender label
-- (docs/story.md), so "sister" and "brother" are both wrong here by construction.
--
-- Odo is the household's steward, and he is the alarm. He does not survive the night (see
-- prologue_flee): a surviving member of the household is a witness, and every scene where the capital
-- turns the avatar away becomes a scene the player argues with.
--
-- Rowan is already sworn here -- she is the Order's knight on the post Bellmere sits behind, and the
-- baron's child is what that posting turned into. She taught the avatar the sword, which is the only
-- reason a small holding's child can hold one. The oath she says in the ash afterwards is NOT this
-- assignment; see prologue_flee for the difference, which is the whole of her line.
return {
    title = "Bellmere",
    cast  = { { id = "sibling", name = "Ellis" }, { id = "steward", name = "Odo" }, "character_rowan", "character_avatar" },

    script = {
        { "sibling", "Father wants the whole house at the table tonight, before the roads close.", tag = 1 },
        { "character_avatar", "He'll say that, and then he'll eat where he always eats. At his desk.", tag = 2 },
        { "sibling", "Then we sit and wait for him, {name}. Both of us. I am not doing it on my own.", tag = 3 },
        { "steward", "Ser Rowan. {name}. There is fire on the eastern fields!", tag = 4 },
        { "steward", "Not one rick burning. The whole line of them, from the mill road down to the east wall.", tag = 5 },
        { "character_rowan", "That is an army. The Demon Lord's people burn a valley from its edge inward.", tag = 6 },
        { "sibling", "I'll get father and the household onto the west road. Ring the bell, Odo, and keep ringing it.", tag = 7 },
        { "character_rowan", "The east wall is nearest and it is thinnest. {name}, with me. We hold the lane while the town empties.", tag = 8 },
        { "character_avatar", "And the house?", tag = 9 },
        { "character_rowan", "Ellis will bring them out. Stay at my shoulder and do what I tell you.", tag = 10 },
    },
}
