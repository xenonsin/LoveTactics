-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Touchstone",
    cast  = {
        "touchstone", "character_avatar",
        { id = "character_rowan", when = { has = "character_rowan" } },
        { id = "character_saber", when = { has = "character_saber" } },
        { id = "character_amana", when = { has = "character_amana" } },
        { id = "character_clem",  when = { has = "character_clem" } },
        { id = "character_gyeom", when = { has = "character_gyeom" } },
        { id = "character_kaya",  when = { has = "character_kaya" } },
        { id = "character_ren",   when = { has = "character_ren" } },
    },

    script = {
        { "touchstone", "Four houses dig that hole and not one of them trusts the other three to say what came out of it. So they pay me to say it. Everything that comes up unnamed comes up here.", tag = 1 },
        { "character_avatar", "You can tell what a thing is by looking at it?", tag = 2 },
        { "touchstone", "By the mark it leaves on the stone. I charge for the work, {name}, not for the answer. You pay the same whether I like what I find or not.", tag = 3 },
        { "touchstone", "And if you would rather not know, I will take it off you for what the work would have cost. I keep the last few on the shelf. Wanting one back costs more than I paid, which is the price of having changed your mind.", tag = 4 },

        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Name the blades first, {name}. A coat you cannot name will still stop a blow. A blade you cannot name does nothing at all.", tag = 5 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "Or you could swing it once and find out.", tag = 6 },
            { "touchstone", "People have. I have named what was left of two of them.", tag = 7 },
        } },
        { when = { has = "character_amana" }, script = {
            { "character_amana", "You hold other people's things and you give them back whole. That is a good trade to be in.", tag = 8 },
        } },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "I have seen a weigher put a thumb on a scale. Both thumbs, once.", tag = 9 },
            { "touchstone", "Not on this counter.", tag = 10 },
            { "character_clem", "No. I checked.", tag = 11 },
        } },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "How long until you can do it without the stone?", tag = 12 },
            { "touchstone", "I still use the stone.", tag = 13 },
        } },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "You do not have to name all of them. Name what you will carry, and sell the rest before the shelf forgets them.", tag = 14 },
        } },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "That is an assayer's stone. My college kept one and never once used it honestly.", tag = 15 },
        } },

        { "touchstone", "Put it on the stone when you are ready. I am here all day and most of the night.", tag = 16 },
    },
}
