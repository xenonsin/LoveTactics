-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE FIRST SCENE IN THE GAME, and it is played OVER THE BOARD (data/tutorials/village.lua's
-- `opening`, fielded by states/battle.lua). A conversation is a global overlay drawn on top of a
-- frozen state, so the lane, the party and the five imps are all sitting there behind Rowan while
-- she talks. It is the last still moment before anyone swings.
--
-- IT USED TO BE THE SECOND SCENE. `conversation_prologue_intro` stood in front of it: a five-line
-- visual-novel beat in the burning house, cast as the sibling Bryn plus Rowan plus the avatar, and
-- it is DELETED. Two reasons, and the second is the real one.
--
--   * It costs a screen. New Game went title, creation, a black backdrop with three cast slots on
--     it, and only then a tactics board. Everything that scene established is establishable here,
--     with the fight already standing behind the text.
--   * NOTHING IN IT WAS DRAWN. The portrait set is uncommissioned, so its whole cast rendered as
--     grey letterboxes with an initial in them (ui/dialogue.lua drawPortrait), against a flat black
--     fill, in silence. The words were doing the work of a visual track that was not there. Over the
--     board there IS a visual track, and it is the thing being talked about.
--
-- WHAT THE CUT HAD TO CARRY OVER. The sibling went with the scene and is not replaced (see
-- data/characters/character_avatar.lua on what the unchosen body is for now). The father did not:
-- he is put on the west road here so that his death lands in prologue_flee on somebody the player
-- has heard of. And Rowan is not introduced by name or office -- prologue_flee does that one scene
-- later ("Keep the baron's child alive"), which is a scene sooner than it used to.
--
-- THE RIFT IS THE POINT OF IT. The old opening named a rift and glossed nothing, on the theory that
-- a hole standing open over your own field explains itself. It does not: it was the first noun in
-- the game and it arrived attached to nothing. So the avatar asks, and Rowan answers in three plain
-- lines. That they open anywhere, that nobody has ever shut one, and that things climb out while one
-- stands, is the premise of the whole game and is said out loud in the first thirty seconds.
--
-- ROWAN SPEAKS ALL OF IT, and the avatar does not speak until prologue_flee. A draft gave the avatar
-- the question that opens the exposition -- the register a player-insert is allowed, and a fix for the
-- eleven straight lines the player used to spend being talked at. It is refused here on purpose, and
-- tests/tutorial_spec.lua is what refuses it: a lesson's opening establishes whose voice teaches for
-- the next seven steps, and a second speaker in it costs exactly that. So the exposition is not earned
-- by a question, it is earned by her POINTING -- "that torn place above the fire" names what is on
-- screen, which is the same job the question was doing. The avatar's first line is one scene later
-- than it reads here and two scenes earlier than it used to be, because the cut moved everything up.
--
-- Nothing here asks for the compact staging (no busts, no title, barely any dim). It does not have
-- to: states/battle.lua applies it to EVERY conversation it plays, because that is a fact about
-- being over a board rather than about this scene.
--
-- The beat the fight needs most is still the last line: without it, Rowan's opening kill resolves in
-- the first half-second of the battle, before the player has worked out what they are looking at.
-- Here they dismiss the box themselves, and the blow lands into a board they have already read.
return {
    title = "Bellmere",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "Look at the field, {name}! Bellmere is burning.", tag = 1 },
        { "character_rowan", "That torn place above the fire is a rift. It opened at dusk.", tag = 2 },
        { "character_rowan", "They open where they please, all over the world. No one has ever shut one.", tag = 3 },
        { "character_rowan", "Demons climb out while it stands. More are coming up behind these.", tag = 4 },
        { "character_rowan", "Your father has the town on the west road.", tag = 5 },
        { "character_rowan", "This is the only lane up from the field. We hold it until they are clear, {name}!", tag = 6 },
        { "character_rowan", "Two of them have seen us. Watch how I take mine.", tag = 7 },
    },
}
