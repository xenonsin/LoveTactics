-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- PLAYED ON THE FLOOR, over the opened crate. Ren joins here: states/game.lua's errand payout recruits
-- `rewardCharacter` immediately before this plays, so the join banner drains onto the end of it.
--
-- IT USED TO BE THE CRUCIBLE'S DEBRIEF: seals checked in the city, the college told it came back intact,
-- an invitation to the counter. The point of her ask is that the college's word for what was in the box
-- was a lie, so the scene that ends it belongs to the person who opened it.
return {
    title = "Intact",
    cast  = { "character_avatar", "character_ren" },

    script = {
        { "character_ren", "Seals whole. Straw dry. Nothing has gone off inside it.", tag = 30 },
        { "character_ren", "That is the word they use. Intact. Never once alive.", tag = 31 },
        { "character_ren", "You asked what was in the box before you opened it. I go where you go.", tag = 32 },
    },
}
