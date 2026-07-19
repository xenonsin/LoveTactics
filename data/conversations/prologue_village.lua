-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Played OVER THE BOARD, at the opening of the village fight (data/tutorials/village.lua's
-- `opening`, fielded by states/battle.lua). A conversation is a global overlay drawn on top of a
-- frozen state, so the lane, the party and the five imps are all sitting there behind Rowan while
-- she talks -- which is the point. prologue_intro says the demons are coming; this one is said with
-- them already on screen, and it is the last still moment before anyone swings.
--
-- Nothing here asks for the compact staging (no busts, no title, barely any dim). It does not have
-- to: states/battle.lua applies it to EVERY conversation it plays, because that is a fact about
-- being over a board rather than about this scene. Written for anywhere else, these same lines would
-- get the ordinary visual-novel treatment.
--
-- It also buys the beat the fight needs most: without it, Rowan's opening kill resolves in the first
-- half-second of the battle, before the player has worked out what they are looking at, and the
-- demonstration she is making goes right past them. Here they dismiss the box themselves, and the
-- blow lands into a board they have already been looking at.
return {
    title = "The Lane",
    cast  = { "character_knight" },

    script = {
        { "character_knight", "Look at it, {name}. The mill, the eastern row, the well we drew from this morning -- all of it, inside a night.", tag = 1 },
        { "character_knight", "This is not a raid. The Demon Lord's army empties whole valleys like this and moves on before the ash is cold.", tag = 2 },
        { "character_knight", "Two of them have seen us, and they will not come to you. Watch how I take mine.", tag = 3 },
    },
}
