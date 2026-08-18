-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Gatekeeper",
    cast  = { "character_saber", "colosseum", { id = "guild", name = "Guild Envoy" } },

    script = {
        { "character_saber", "Enough. Enough! It's been years since anyone put me on my back on this sand.", tag = 1 },
        { "character_saber", "I've watched this place feed fighters to its patron, one after another. I will not be fed. And you two. No house behind you, and you still put me down.", tag = 2 },
        { "character_saber", "Walk out slow. I'll catch you past the gate. There's a thing I mean to ask, and not with a booking man breathing on it.", tag = 5 },
        { "guild", "Well fought. The Adventurers' Guild is always short of people who live through their first bout.", tag = 3 },
        { "guild", "You want the Demon Lord? So does everyone who's lost a home. But it is only strong because of its seven. Its generals, its appetites. Unmake them one by one, and the crown is hollow.", tag = 4 },
        { "colosseum", "And the houses pay attention to who does the work. Mine has a counter on the markets. It is open to you now. Come and spend.", tag = 15 },
    },
}
