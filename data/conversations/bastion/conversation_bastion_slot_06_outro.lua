-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 6 OF 10 (docs/temptation.md). The slot the whole ten-slot table calls COMPLICITY: the player
-- stops being someone the offer is made to and becomes the hand that carries it out. Signing names
-- onto a roll that has nobody behind them is what the order has been doing with Acedia's forty-one for
-- fifteen years, and slot 9 is where the player finds out that is what it was. Doing it first,
-- knowingly, for money, is the arrangement of this line.
--
-- Her closing line was authored before this system existed and is now doing double duty: "I have
-- already heard what I would say" lands on the shorter line at the tent OR on what she just signed.
return {
    title = "The Muster Tent",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "Shorter line at the muster tent this time.", tag = 1 },
        { "character_rowan", "That's the third season running.", tag = 2 },
        { "character_rowan", "The quartermaster wants the roll closed at sixty and he has forty-four.", tag = 4 },
        { "character_rowan", "He is not asking us to lie. He is asking us to write down sixty and let the season start.", tag = 5 },
        { "character_avatar", "...", tag = 6, choices = {
            { "\"Forty-four is what he has.\"", tag = 7, goto = "refuse" },
            { "\"Write sixty.\"", tag = 8, goto = "took", effect = { gold = 220, take = "bastion" } },
            { "\"You've been on a roll like that, Rowan. Sign it.\"", tag = 9, goto = "with", effect = { gold = 220, take = "bastion", press = "bastion" } },
        } },
        { "character_rowan", "Forty-four. He can explain the gap to somebody above him.", tag = 10, id = "refuse", goto = "after" },
        { "character_rowan", "Sixty on paper and forty-four on the line. I have seen where that ends.", tag = 11, id = "took", goto = "after" },
        { "character_rowan", "...I have been a name on a roll that was short.", tag = 12, id = "with" },
        { "character_rowan", "Nobody meant anything by it. It is how a season gets started.", tag = 13 },
        { "character_rowan", "Give me the pen.", tag = 14 },
        { "character_rowan", "Don't say anything about it, {name}. I have already heard what I would say.", tag = 3, id = "after" },
    },
}
