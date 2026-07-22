-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Hunter's Lodge",
    cast  = { "hunters_lodge", "character_avatar", { id = "character_kaya", when = { has = "character_kaya" } } },

    script = {
        { "hunters_lodge", "The Lodge. We clear the beasts that would eat your children and feed your town on what's left -- honest work, honest coin. The board's always open. Take a bounty, take a trophy.", tag = 1 },
        { "character_avatar", "Always open. It never closes?", tag = 2 },
        { "hunters_lodge", "The wild always makes more game. That is the mercy of it -- there is always another beast worth killing. Rank up, and one day you'll be a Grand Hunter, and they'll carve your name on the wall.", tag = 3 },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "I have read the names on that wall. Some of them I hunted.", tag = 4 },
            { "hunters_lodge", "...You take only what you need, girl. That is why we could never crown you. You were the finest tracker the wood ever grew.", tag = 5 },
            { "character_kaya", "It is why the wood never turned on me. Sell {name} the bows. Keep the crown.", tag = 6 },
        } },
        { "hunters_lodge", "As you like. The board's open. There's always another beast worth killing.", tag = 7 },
    },
}
