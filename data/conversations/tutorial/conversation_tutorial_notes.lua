-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE TUTORIAL WINDOWS' WORDS, all of them, in one file so a translator has one place to work. Each
-- window is two nodes -- its title and its body -- fetched by id (Locale.line) rather than played in
-- order: this is a hint bag, not a scene, and nothing here is ever spoken by anybody.
--
-- A WINDOW EXPLAINS A FEATURE; a bubble points at a control. That line is drawn in
-- ui/panels/tutorial_note.lua and it is why these three are long: a tally with three rules and a
-- failure state, a rule list the fight can be handed to, a ladder every body climbs. The bubbles' own
-- words are next door in conversation_tutorial_city.lua.
--
-- WHO FIELDS THEM:
--   tally    states/gate.lua      -- the first time the company has turned back and the meter is drawn
--   tactics  ui/panels/party.lua  -- the Armory tab that arrives with the first descent
--   classes  ui/panels/party.lua  -- ...and the tab beside it, which has been there all along
--
-- THE WINDOW'S OWN CHROME IS HERE TOO -- the three `dismiss_*` lines, which are the footer under every
-- one of these bodies (ui/panels/tutorial_note.lua). Three lines rather than one with a token, because
-- they are not one sentence with a word swapped: a pad names a face button, a finger taps, and a mouse
-- has to be told about the keyboard's way out as well. Which one is drawn is InputMode.pick's answer,
-- and the id it picks is what gets looked up here. They deliberately do NOT use {select}: that token
-- means "the confirm button", and this window is dismissed by any button at all.
--
-- THE TALLY'S FIGURES ARE TOKENS ({stair}, {wipe}, {seal}, {max}), filled from models/descent.lua's
-- own constants at draw time. Two reasons, and the second is the one that matters here: a number typed
-- into the sentence goes stale the day the constant moves, and it lands in the middle of a clause where
-- a translator cannot move it. Keep the braces and the spelling exactly.
--
-- The cast is Rowan because a conversation must have one, not because she says any of this. These are
-- the interface's voice, the same way the flight leg's coach lines are.
return {
    title = "What the Screen Owes You",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "The Tally", tag = 1, id = "tally_title" },
        { "character_rowan", "Beside the stair is a count of what is forming on the floors you have left behind. Nothing down there is born -- it forms, and it does not stop.\n\nClimb out early and the count rises by {stair}. Lose the company and it rises by {wipe}. Every new floor you reach takes one back off, and sealing a circle takes off {seal}.\n\nFill all {max} marks and what is below stops waiting to be found. It comes up the stair on its own -- which is what happened to Bellmere.", tag = 2, id = "tally_body" },
        { "character_rowan", "Tactics", tag = 3, id = "tactics_title" },
        { "character_rowan", "Your company can be taught to fight on its own.\n\nThis tab gives each body a list of rules, read top to bottom on its turn -- who to strike, when to fall back, what to save its breath for. A body with no rule it can obey simply waits for you.\n\nIn a fight, Auto hands the turn to those rules. Turn it off at any time and the company is yours again. Nothing is decided that you cannot take back.", tag = 4, id = "tactics_body" },
        { "character_rowan", "Classes", tag = 5, id = "classes_title" },
        { "character_rowan", "Every body in your company stands in one class, and that is what its levels buy -- what a knight gains on the way up is not what a rogue gains.\n\nA class climbs by being fought in: every action banks technique against the house the thing in the hand belongs to. Levels in a house open the classes beyond it, and a class still shut stands in the list with its name and the level that opens it, so there is always something to climb towards.\n\nChanging class is free and takes nothing back. Levels already earned stay earned -- a change costs you the levels ahead, never the ones behind -- so it is a choice you can afford to make early.", tag = 6, id = "classes_body" },

        { "character_rowan", "A to continue", tag = 7, id = "dismiss_pad" },
        { "character_rowan", "Tap to continue", tag = 8, id = "dismiss_touch" },
        { "character_rowan", "Click, or press Enter to continue", tag = 9, id = "dismiss_key" },
    },
}
