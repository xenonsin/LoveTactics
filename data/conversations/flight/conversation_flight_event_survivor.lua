-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Stop 4 of the city sweep (states/prologue.lua's FLIGHT_QUEST), and the leg's second CHOICE. She is
-- one of the survivors the errand named, found under a collapsed block rather than in a wood: Act 0
-- happens inside the capital now.
--
-- THE CHOICE IS A TRADE, like the shrine's: what she knows (Mark Target, and where the demons went)
-- against what she is owed (the Assayer's Eye -- alchemist, the class this stop introduces). BOTH
-- branches set `met_the_survivor`, so the flag says she was met and never which way it went.
-- tests/story_effect_spec.lua pins the effects; states/prologue.lua's SCENE_GIFTS hands the lens over
-- when Act 0 is skipped, which is why that branch's grant is the one named there.
--
-- Both branches goto `part`, which is the line that ends the stop. Keep that shape.
--
-- ROWAN SPEAKS IT ALL. The avatar is silent for the whole of Act 0 as it currently stands.
return {
    title = "A Voice in the Rubble",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "Hold. Someone's under that wall, hurt and trying not to make a sound.", tag = 1 },
        { "character_rowan", "Easy. We're not with the things that did this. Choose...", tag = 2, choices = {
            { "Ask which way the demons went.", tag = 3, goto = "ask", effect = { grant = "ability_mark_target", flag = "met_the_survivor" } },
            { "Share what we're carrying, and move on.", tag = 4, goto = "give", effect = { grant = "ability_assayers_eye", flag = "met_the_survivor" } },
        } },
        { "character_rowan", "North, through the market, in numbers. She gave us the tell as well: mark one before you strike and you'll see where its guard runs thin.", tag = 5, id = "ask", goto = "part" },
        { "character_rowan", "Not much to spare, and she took it kindly. She pressed her lens on you for it: look through that and a demon's satchel keeps nothing back.", tag = 6, id = "give", goto = "part" },
        { "character_rowan", "An apothecary, before all this. She can make the square on her own now. Let's keep clearing, {name}.", tag = 7, id = "part" },
    },
}
