-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 5 OF 10 (docs/temptation.md). No mouth this time, and that is the escalation: the fort is
-- empty, the offer is just lying there, and the player has learned the shape well enough to hear it
-- without anybody saying it. Acedia's company walked out of Greywatch and left a full armoury standing
-- -- because they were paid in something else, and steel had stopped being what they wanted.
return {
    title = "The Bar",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "{name}. The bar. Look at the bar.", tag = 1 },
        { "character_rowan", "It's on the ground. On the INSIDE. You cannot lift a gate-bar from the wrong side of a gate. That is the entire point of a bar.", tag = 2 },
        { "character_rowan", "Someone in this fort opened it.", tag = 3 },
        { "character_rowan", "She died holding a gateway that was already standing open behind her. Fifteen years and nobody in the order has said that out loud.", tag = 4 },
        { "character_rowan", "They let her name carry a doctrine and they never told a single one of us she was betrayed.", tag = 5 },
        { "character_rowan", "The armoury is still full, {name}. Racked and oiled and sixty spears deep.", tag = 7 },
        { "character_rowan", "Forty-one people walked out of this fort and not one of them took a weapon with them.", tag = 8 },
        { "character_avatar", "...", tag = 9, choices = {
            { "\"Then it stays here.\"", tag = 10, goto = "refuse" },
            { "\"Load it up.\"", tag = 11, goto = "took", effect = { grant = "weapon_exposing_pike", gold = 180 } },
            { "\"They didn't want it, Rowan. You should have it.\"", tag = 12, goto = "with", effect = { grant = "weapon_exposing_pike", gold = 180 } },
        } },
        { "character_rowan", "It stays. It is a grave, and that is grave goods.", tag = 13, id = "refuse", goto = "after" },
        { "character_rowan", "...Fine. It is only steel. She is not in it.", tag = 14, id = "took", goto = "after" },
        { "character_rowan", "...", tag = 15, id = "with" },
        { "character_rowan", "I trained on this rack. I know the spacing of it in the dark.", tag = 16 },
        { "character_rowan", "All right. One. I will carry one of them, and I will carry it properly.", tag = 17 },
        { "character_rowan", "I want the file. Whatever the archive kept on Greywatch, I want it in my hands.", tag = 6, id = "after" },
    },
}
