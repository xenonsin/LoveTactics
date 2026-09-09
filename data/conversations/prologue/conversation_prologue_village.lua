-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE FIRST SCENE IN THE GAME, and it is played OVER THE BOARD (data/tutorials/village.lua's
-- `opening`, fielded by states/battle.lua). A conversation is a global overlay drawn on top of a
-- frozen state, so the lane, the party and the five imps are all sitting there behind Rowan while
-- she talks. It is the last still moment before anyone swings.
--
-- IT IS THREE LINES, AND THAT IS THE DESIGN. An earlier draft ran to eight and spent them on
-- exposition -- what a rift is, that nobody has ever shut one, what the charter had promised, where
-- the townspeople were running. All of it was true and none of it was watchable: the player's first
-- thirty seconds in the game were a wall of text over a board they had not read yet. What is left is
-- only what the next click needs -- what those things are, that they are the small kind, and that
-- Rowan is about to kill one in front of you.
--
-- WHAT WENT WITH THE CUT, so a later pass knows it is missing rather than assuming it is said: the
-- rift is NAMED here and glossed nowhere. That they open anywhere, that no one has ever closed one,
-- and that things climb out while one stands, is the premise of the whole game and it now waits for a
-- later scene to say out loud. The evacuation and the under-read charter went too, and nothing
-- downstream asks for them any more: conversation_prologue_flee leaned on both, and that scene has
-- since been rewritten to two lines and folded into conversation_prologue_ruins.
--
-- IT USED TO BE THE SECOND SCENE. `conversation_prologue_intro` stood in front of it: a five-line
-- visual-novel beat in the burning house, cast as the sibling Bryn plus Rowan plus the avatar, and
-- it is DELETED. It cost a screen -- New Game went title, creation, a black backdrop with three cast
-- slots on it, and only then a tactics board -- and NOTHING IN IT WAS DRAWN. The portrait set is
-- uncommissioned, so its whole cast rendered as grey letterboxes with an initial in them
-- (ui/dialogue.lua drawPortrait), against a flat black fill, in silence. Over the board there IS a
-- visual track, and it is the thing being talked about.
--
-- THE FIGHT IS A JOB, NOT A HOMECOMING. The avatar has no tie to this place and no rank anywhere:
-- they are a new hand on a hired party, and Rowan is the senior hand who trained them. That is the
-- whole relationship -- two friends on the same payroll -- and it is why nobody in this prologue
-- swears anything to anybody. The earlier premise made the avatar the baron of Bellmere's child and
-- Rowan a knight the Order had POSTED to that child; both are gone, and with them the burning
-- household and the sibling.
--
-- The place itself is being re-premised around this scene: the prologue happens IN THE CITY, a breach
-- has opened inside it, and the party is hired to deal with the fallout. The town called Bellmere is
-- gone from Act 0 with it -- what is left of that name lives in the Count's lore and the Gate's own
-- stair text, which still cite it as a place that fell.
--
-- ROWAN SPEAKS ALL OF IT. That is not a stylistic preference, it is tests/tutorial_spec.lua: a
-- lesson's opening establishes whose voice teaches for the next seven steps, and a second speaker in
-- it costs exactly that. (The avatar is silent for the whole prologue as it currently stands -- their
-- only lines were prologue_flee's, and that scene is now two lines of Rowan's inside prologue_ruins.)
--
-- Nothing here asks for the compact staging (no busts, no title, barely any dim). It does not have
-- to: states/battle.lua applies it to EVERY conversation it plays, because that is a fact about
-- being over a board rather than about this scene.
--
-- The beat the fight needs most is the last line: without it, Rowan's opening kill resolves in the
-- first half-second of the battle, before the player has worked out what they are looking at. Here
-- they dismiss the box themselves, and the blow lands into a board they have already read.
return {
    title = "The Breach",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "The demons that breached through the rift are up ahead, {name}.", tag = 1 },
        { "character_rowan", "They look like simple imps, so the guild report seems accurate.", tag = 2 },
        { "character_rowan", "Strike before they start to notice us. Watch this!", tag = 3 },
    },
}
