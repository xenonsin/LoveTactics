-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Arcanum",
    cast  = { "arcanum", "character_avatar", { id = "character_gyeom", when = { has = "character_gyeom" } } },

    script = {
        { "arcanum", "The Arcanum. We win the wars the crown cannot and turn back the plagues its physicians can't name. Buy what you like -- everything on this shelf was earned by someone.", tag = 1 },
        { "character_avatar", "Earned by whom?", tag = 2 },
        { "arcanum", "Does it matter, so long as it works? No one else can do what we do. That is the beginning and end of the question.", tag = 3 },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "It matters. It always mattered.", tag = 4 },
            { "arcanum", "Sister. You were the finest hand on this floor before you grew a conscience over it.", tag = 5 },
            { "character_gyeom", "I grew eyes. Sell {name} the wares, and keep the rest.", tag = 6 },
        } },
        { "arcanum", "...As you wish. The shelf is open. We only ask that what we sell be used as we intended -- and we always know when it is not.", tag = 7 },
    },
}
