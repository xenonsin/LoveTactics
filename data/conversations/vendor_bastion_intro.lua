-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Those Who Hold",
    cast  = { "bastion", "character_avatar", { id = "character_knight", when = { has = "character_knight" } } },

    script = {
        { "bastion", "The Watch outfits those who hold -- shields that outlast the arm behind them, mail a knight can be found standing in. We do not arm those who run. State your post, or your reason for having none.", tag = 1 },
        { "character_avatar", "I hold what's mine. That's post enough.", tag = 2 },
        { when = { has = "character_knight" }, script = {
            { "character_knight", "I held a post on this order's line before I ever held a sword for {name}. Greywatch. The quartermaster knows the face, if not the years on it.", tag = 3 },
            { "bastion", "Squire Rowan. Greywatch's own. It is an honor to arm you again.", tag = 4 },
            { "character_knight", "It is Rowan of no post now. I kept the oath and gave up the wall -- and I hold something better than a line these days. Outfit us both.", tag = 5 },
        } },
        { "bastion", "Hold until relieved, then. The shelf is yours -- and the order remembers the ones who stay.", tag = 6 },
    },
}
