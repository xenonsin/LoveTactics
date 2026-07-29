-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Undercroft",
    cast  = { "undercroft", "character_avatar", { id = "character_clem", when = { has = "character_clem" } } },

    script = {
        { "undercroft", "No sign, no door you'd notice. Good -- you found us anyway. The Undercroft looks after its own, friend. Debts, and the quiet murder of the people who won't pay them. Everything on this floor belonged to someone else once. That's just business.", tag = 1 },
        { "character_avatar", "And the people it belonged to?", tag = 2 },
        { "undercroft", "Owed. Everyone's owed, up above -- your house, your city's water, your king's war. We just hold the note. A debt is a debt. That's not cruelty, that's the world.", tag = 3 },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "I used to say that word for word. I collected on it, too. That's the lie -- 'we look after our own,' over a floor that owns every soul on it.", tag = 4 },
            { "undercroft", "Clem. You were the best blade we ever ran. Then you started burning the paper.", tag = 5 },
            { "character_clem", "I started reading it. Sell {name} the kit. Keep the family.", tag = 6 },
        } },
        { "undercroft", "As you like. Floor's open. Everything's for sale -- and everything's owed.", tag = 7 },
    },
}
