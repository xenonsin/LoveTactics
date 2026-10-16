-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- This header survives a re-stamp: the tool reads the leading run of `--` lines back off disk and
-- re-emits it (tools/extract_strings.lua, `headerLines`). A comment further DOWN the file does not.
--
-- THE CHARTER'S ROLL. Played the beat after the first street is held, and it hands straight on to
-- character creation (states/prologue.lua, states/character_creation.lua), which used to be the
-- first screen of a New Game. A New Game now reaches the board on its first click, and who the player
-- is gets asked once they have fought as somebody.
--
-- WHY IT IS ROWAN AND NOT A STRANGER ASKING. She taught the newest hand the sword, so she cannot ask a
-- name she does not know. What she can do is put you on the Ninth Charter's books now the first job is
-- done -- name and people -- which is the two things the screen after this asks, in that order. It
-- asks no trade: the avatar starts as a Novice and earns every class afterwards.
--
-- THE LINES ARE PLACEHOLDERS for the author (2026-10-15). Keep the two nouns, or tell the screen.
return {
    title = "The Charter's Roll",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "That's the street held. Not bad for a first job.", tag = 1 },
        { "character_rowan", "The Charter will want you on its roll properly now. Name and people.", tag = 2 },
        { "character_rowan", "Write it the way you want it read.", tag = 3 },
    },
}
