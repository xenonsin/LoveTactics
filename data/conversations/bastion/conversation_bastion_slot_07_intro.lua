-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 7 OF 10, AND THE ONE PLAIN WARNING (docs/temptation.md). Slot 7 is "the turn" in every line's
-- ten-slot table (docs/story.md), and it is the one beat where the system stops being read in her voice
-- and says itself out loud.
--
-- THE WARNING IS GATED, not unconditional. `breaking_bastion` is stamped by Temptation.record the
-- moment this line passes the point where it can still end in `held` -- so a player who has been
-- refusing never hears it, and a player who is going to lose her hears it while there are still three
-- quests left to stop in. A permanent counter would have to be read and optimised; this is the same
-- information delivered once, by the person it is about, at the only moment it can change anything.
--
-- She does not name a number and she does not threaten to leave. She would not know how to say either.
-- What she says is what she has actually noticed, which is that she has stopped arguing.
--
-- The offer itself is UNGATED and sits after the warning, which is the point of putting them in one
-- scene: the sentence and the next chance to say yes to it are on the same screen.
return {
    title = "What It Stopped Reading",
    cast  = { "bastion", "character_rowan", "character_avatar" },

    script = {
        { "bastion", "The archive keeps everything. Including what it stopped reading.", tag = 1 },
        { "character_rowan", "Greywatch. The relief order that was cut for it. I want the date on the seal.", tag = 2 },
        { "bastion", "The archivist will not give you that.", tag = 3 },
        { "character_rowan", "I know. That's why I'm bringing {name} and not a requisition.", tag = 4 },
        { when = { flag = "breaking_bastion" }, script = {
            { "character_rowan", "{name}. Before we go in there.", tag = 5 },
            { "character_rowan", "I have gone along with you a number of times now and I would like to say that out loud, because I do not think either of us has been counting.", tag = 6 },
            { "character_rowan", "I am not accusing you of anything. Every one of them was reasonable. I checked. That is what is bothering me.", tag = 7 },
            { "character_rowan", "There used to be a point where I said no to you, and I cannot find where it went.", tag = 8 },
            { "character_rowan", "Ask me again and I do not think I will find it this time either.", tag = 9 },
        } },
        { "bastion", "The archivist takes forty for a shelf he is not watching. He has taken it before.", tag = 10 },
        { "bastion", "There is more on that shelf than one relief order. Muster rolls. Pay books. Fifteen years of the eastern posts.", tag = 11 },
        { "character_avatar", "...", tag = 12, choices = {
            { "\"We take the Greywatch file. Nothing else.\"", tag = 13, goto = "refuse" },
            { "\"Take the shelf.\"", tag = 14, goto = "took", effect = { gold = 260 } },
            { "\"Rowan. You know what's worth taking. Pick.\"", tag = 15, goto = "with", effect = { gold = 260 } },
        } },
        { "character_rowan", "One file. I came for one file.", tag = 16, id = "refuse", goto = "end" },
        { "character_rowan", "All of it, then. It is only paper and it is already forgotten.", tag = 17, id = "took", goto = "end" },
        { "character_rowan", "...", tag = 18, id = "with" },
        { "character_rowan", "The pay books. Those are the ones worth having.", tag = 19 },
    },
}
