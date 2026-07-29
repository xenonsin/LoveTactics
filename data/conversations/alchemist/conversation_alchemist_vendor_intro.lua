-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Crucible",
    cast  = { "alchemist", "character_avatar", { id = "character_ren", when = { has = "character_ren" } } },

    script = {
        { "alchemist", "The Crucible. We refine your gear and brew your medicine, and we teach the one truth the others are too timid for: excellence is a substance, not a self. No one is born better. Anything can be transferred.", tag = 1 },
        { "character_avatar", "Transferred from whom?", tag = 2 },
        { "alchemist", "From a source. Does a formula have feelings? A self is inventory, friend -- and we are the only ones honest enough to say so. Buy, and be improved.", tag = 3 },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "A self is not inventory. I have held the ones you decanted and dropped. There was someone in each of them.", tag = 4 },
            { "alchemist", "Ren. You could have been a Philosopher. Instead you give the Work away and weep over spoiled batches.", tag = 5 },
            { "character_ren", "They were not batches. Sell {name} the tinctures. Keep the philosophy.", tag = 6 },
        } },
        { "alchemist", "As you wish. The shelf is open. Improvement is only ever a purchase away.", tag = 7 },
    },
}
