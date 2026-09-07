-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The shopkeeper greets you and the shopkeeper is the house's own person; the door is open because the
-- company has been fighting in this discipline. See data/conversations/bastion/ for both, and for why
-- Rowan is the only companion a first-visit greeting can carry.
return {
    title = "The Undercroft",
    cast  = { "undercroft", "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "undercroft", "There is a hand in your company who knows the trade. We hear about quiet work, friend. That is why this counter is open to you.", tag = 1 },
        { "undercroft", "No sign, no door you would notice, and you found us anyway. Everything on this floor belonged to somebody else once.", tag = 2 },
        { "character_avatar", "And the people it belonged to?", tag = 3 },
        { "undercroft", "Owed. Everyone is owed, up above. We only hold the note. That is not cruelty, that is the world.", tag = 4 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Buy from him and pay him in coin, {name}. Owe this house nothing.", tag = 5 },
        } },
        { "undercroft", "The floor is open. Everything is for sale, and everything is owed.", tag = 6 },
    },
}
