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
-- BELLMERE IS A POSTING, NOT A HOME. The avatar has no tie to this town and no rank anywhere: they
-- are a new hand of the NINTH CHARTER, a chartered rift company working the eastern shires, and
-- Rowan is the senior hand who trained them. That is the whole relationship -- two friends on the
-- same payroll -- and it is why nobody in this prologue swears anything to anybody. The earlier
-- premise made the avatar the baron of Bellmere's child and Rowan a knight the Order had POSTED to
-- that child; both are gone, and with them the burning household and the sibling.
--
-- What the charter buys the scene is the one thing the old rank bought it and more cheaply: a
-- reason for Rowan to be teaching, a reason for the avatar to be here at all, and a trade the whole
-- rest of the game is already inside. Line 5 is where it is said -- the job was billed as a field
-- tear and a dozen imps, and the paper was wrong. Everything that goes wrong in Act 0 goes wrong
-- because a charter under-read a rift.
--
-- THE RIFT IS THE POINT OF IT. The old opening named a rift and glossed nothing, on the theory that
-- a hole standing open over your own field explains itself. It does not: it was the first noun in
-- the game and it arrived attached to nothing. So Rowan answers it in three plain lines. That they
-- open anywhere, that nobody has ever shut one, and that things climb out while one stands, is the
-- premise of the whole game and is said out loud in the first thirty seconds. It survives the
-- re-premise unchanged: a new hand on a first job has exactly as much need to hear it as a baron's
-- child did, and tests/prologue_spec.lua pins all three halves of it.
--
-- ROWAN SPEAKS ALL OF IT, and the avatar does not speak until prologue_flee. A draft gave the avatar
-- the question that opens the exposition -- the register a player-insert is allowed, and a fix for the
-- eleven straight lines the player used to spend being talked at. It is refused here on purpose, and
-- tests/tutorial_spec.lua is what refuses it: a lesson's opening establishes whose voice teaches for
-- the next seven steps, and a second speaker in it costs exactly that. So the exposition is not earned
-- by a question, it is earned by her POINTING -- "that torn place above the fire" names what is on
-- screen, which is the same job the question was doing.
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
        { "character_rowan", "Our charter said a field tear and a dozen imps. Whoever wrote it never rode out here to look.", tag = 8 },
        { "character_rowan", "The town is running for the west road. This is the only lane up from the field.", tag = 9 },
        { "character_rowan", "We hold it until they're clear, {name}. First job or not, you're holding it with me.", tag = 10 },
        { "character_rowan", "Two of them have seen us. Watch how I take mine.", tag = 7 },
    },
}
