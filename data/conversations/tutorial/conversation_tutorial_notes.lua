-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE TUTORIAL WINDOWS' WORDS, all of them, in one file so a translator has one place to work. Each
-- window is two nodes -- its title and its body -- fetched by id (Locale.line) rather than played in
-- order: this is a hint bag, not a scene, and nothing here is ever spoken by anybody.
--
-- A WINDOW EXPLAINS A FEATURE; a bubble points at a control. That line is drawn in
-- ui/panels/tutorial_note.lua and it is why these are long: a tally with three rules and a failure
-- state, a rule list the fight can be handed to, a ladder every body climbs, a purchase that is handed
-- back at the stair. The bubbles' own words are next door in conversation_tutorial_city.lua.
--
-- WHO FIELDS THEM:
--   tally    states/gate.lua      -- the first time the company has turned back and the meter is drawn
--   tactics  ui/panels/party.lua  -- the Armory tab that arrives with the first descent
--   classes  ui/panels/party.lua  -- ...and the tab beside it, which has been there all along
--   relics   states/game.lua      -- the first relic ever put in front of the company, underground
--   wound    states/hub.lua       -- the Cathedral's mending, on the one visit Xin joins out of it
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
        { "character_rowan", "This meter measures the energy of the rift and tells us if a breach is imminent. It will increase every day, but clearing the champion on each floor reduces the meter.\n\nThe merchants lobby heavily to keep the rift active, but many lives are spent keeping the balance.", tag = 2, id = "tally_body" },
        { "character_rowan", "Tactics", tag = 3, id = "tactics_title" },
        { "character_rowan", "Characters can be taught to fight on their own using tactics.\n\nTactics are prioritized and evaluated from top to bottom and are used when the character is set to auto mode.", tag = 4, id = "tactics_body" },
        { "character_rowan", "Classes", tag = 5, id = "classes_title" },
        { "character_rowan", "Leveling up increases the stats determined by your chosen class. You are free to change classes at any time.\n\nYour class level increases when you use actions in combat. Using an action that's the same class increases your class technique by 2, using an action that's not the same class increases your class technique by 1, and the action's class technique by 1.\n\nClass level unlocks abilities from trainers and new classes, while the technique can be spent to upgrade your items.", tag = 6, id = "classes_body" },
        { "character_rowan", "Relics", tag = 10, id = "relics_title" },
        { "character_rowan", "Relics are bonuses that affect the whole party that only last until you leave the rift.", tag = 11, id = "relics_body" },
        { "character_rowan", "Wounds", tag = 12, id = "wound_title" },
        { "character_rowan", "A body carried out of a fight comes back wounded. Part of its health is set aside and cannot be healed back into, and a body carrying more than one wound fights worse for them.\n\nA wound does not close on its own, and coming home does not close it either. The Inn is the only room that ends one, and it ends one two ways: rest the body, which costs nothing but keeps it out of the company for a few descents, or set the bone, which costs gold and is done before you leave the room.\n\nGold buys speed here and never recovery. Resting is free, always.", tag = 13, id = "wound_body" },
        { "character_rowan", "A to continue", tag = 7, id = "dismiss_pad" },
        { "character_rowan", "Tap to continue", tag = 8, id = "dismiss_touch" },
        { "character_rowan", "Click, or press Enter to continue", tag = 9, id = "dismiss_key" },
    },
}
