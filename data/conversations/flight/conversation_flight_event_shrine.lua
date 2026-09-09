-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Stop 2 of the city sweep (states/prologue.lua's FLIGHT_QUEST), and the leg's first CHOICE. It used
-- to be a wayside shrine on the king's road; Act 0 happens inside the capital now, so it is a street
-- shrine standing in a burned block.
--
-- THE CHOICE IS A TRADE, and that is the whole reason the stop exists: the rite (priest -- Renewal,
-- the class this stop introduces) against a heal you can feel right now. Neither is the right answer
-- and the branch must stay priced that way. The effects are pinned by tests/story_effect_spec.lua and
-- the grant by states/prologue.lua's SCENE_GIFTS, which hands it over when Act 0 is skipped.
--
-- The `pray` branch jumps the `take` line; `take` falls through to `leave`, which both branches end
-- on. Keep that shape -- an id is only reachable by a goto or by falling into it.
--
-- ROWAN SPEAKS IT ALL. The avatar is silent for the whole of Act 0 as it currently stands.
return {
    title = "The Street Shrine",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "A shrine, still standing with the whole block burned around it.", tag = 1 },
        { "character_rowan", "Someone cut a healer's rite into the stone. We can learn it, or we can patch ourselves up and move. Choose...", tag = 2, choices = {
            { "Kneel and learn the rite.", tag = 3, goto = "pray", effect = { grant = "ability_renewal" } },
            { "Tend our wounds and move on.", tag = 4, goto = "take", effect = { heal = 12 } },
        } },
        { "character_rowan", "You have it. That will set a wound to closing, slow but sure. Even one that isn't yours.", tag = 5, id = "pray", goto = "leave" },
        { "character_rowan", "Patched up. We leave the rite for whoever comes through here after us.", tag = 6, id = "take" },
        { "character_rowan", "Now let's keep moving. There's more of this quarter to clear.", tag = 7, id = "leave" },
    },
}
