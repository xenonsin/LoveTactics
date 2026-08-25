-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE BOTTOM OF A DESCENT, played over the Hollow Crown's fight -- the only seam it can speak from at
-- all, since by the time an `outro` runs the target of an `assassinate` objective is already dead.
--
-- WHY THIS EXISTS RATHER THAN THE CAMPAIGN'S. The descent's bottom floor used to open
-- data/conversations/gate/conversation_gate_below_confront.lua, which is the finale of a forty-day
-- campaign: it is written for the avatar, and every one of its beats is the Crown quoting one of the
-- seven dead back at the companion who knew her. A descent has no avatar and no companions
-- (it was handed generic bodies), so that scene played its avatar's lines with no
-- avatar in the company and skipped every `when = { has = }` block it is made of. What was left was a
-- long scene about people nobody in the room had met.
--
-- So the descent gets its own, and the difference between them is the whole of what a descent is. In
-- the campaign the player took the seven apart one at a time over forty days and arrives owed an
-- ending. Here the seven are still standing on their stairs, the company walked past all of them this
-- afternoon, and nobody in it knew a single name before today. The Crown has nothing of its own to say
-- either way; what changes is that here there is nothing to borrow.

return {
    title = "The Hollow Crown",
    cast  = { "character_demon_lord" },

    script = {
        { "character_demon_lord", "You came a long way down to meet me. There is no me to meet.", tag = 1 },
        { "character_demon_lord", "Seven wants, and seven people who agreed to carry one each, because a want cannot walk about on its own. You went past every one of them to get here.", tag = 2 },
        { "character_demon_lord", "You did not know a single one of their names this morning. That is the part I like.", tag = 3 },
        { "character_demon_lord", "I have nothing to say to you that is mine. I never did. Come and take the last of it.", tag = 4 },
    },
}
