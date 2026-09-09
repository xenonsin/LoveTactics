-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Stop 2 of the city sweep (states/prologue.lua's FLIGHT_QUEST), and the leg's first CHOICE. It used
-- to be a wayside shrine on the king's road; Act 0 happens inside the capital now, so it is a street
-- shrine standing in a burned block.
--
-- THE MECHANIC THIS STOP TEACHES IS THE ADJACENCY AURA, and that is what the gift is chosen for. The
-- sweep used to hand over one CLASS per stop and this one was the priest's -- a healing rite, Renewal.
-- The trouble with a class here is that there is nothing on this route to do with one: no second body
-- to build, no shelf to shop, no ladder to climb. What a player CAN use is the thing the gift actually
-- is -- an item in a 3x3 grid with rules about what it touches -- so the shrine now gives the Censer of
-- Dawn, whose whole text is about its NEIGHBOURS ("Adjacent weapons and abilities strike as holy").
-- The heal moved to the last chest, where it is still the only healing ability in Act 0.
--
-- IT PAYS OUT ON THE NEXT BLOCK, which is why this charm and not one of the ones that sharpen a number.
-- Every demon on this route runs a negative holy resist (character_demon_imp.lua: holy -4; the Champion:
-- holy -8), so the lesson and its proof are one step apart -- put it beside your blade and the very next
-- thing you swing at takes more.
--
-- THE CHOICE IS STILL A TRADE, and that is the whole reason the stop exists: the censer against a heal
-- you can feel right now. Neither is the right answer and the branch must stay priced that way. What
-- the branch no longer decides is whether a MECHANIC is met -- compare the survivor at stop 4, where
-- the gate is the lesson and both branches therefore grant it. The effects are pinned by
-- tests/story_effect_spec.lua and the grant by states/prologue.lua's SCENE_GIFTS, which hands it over
-- when Act 0 is skipped.
--
-- ROWAN POINTS AT THE GRID WITHOUT NAMING IT. "Keep it next to whatever you mean to swing" is true in
-- her mouth as a thing you do with a censer and true on the loadout screen as the rule -- which is the
-- one place a conversation can carry an interface lesson without becoming a manual. The coach bubbles
-- (data/conversations/tutorial/conversation_tutorial_flight.lua) are where "cell" and "grid" may live.
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
        { "character_rowan", "There's a censer left burning on the stone. We can carry it, or we can pour out what oil is left and dress our wounds with it. Choose...", tag = 2, choices = {
            { "Take the censer.", tag = 3, goto = "pray", effect = { grant = "utility_censer_of_dawn" } },
            { "Tend our wounds and move on.", tag = 4, goto = "take", effect = { heal = 12 } },
        } },
        { "character_rowan", "Keep it next to whatever you mean to swing. The smoke gets into the steel, and these things do not like being touched by the dawn.", tag = 5, id = "pray", goto = "leave" },
        { "character_rowan", "Patched up. We leave the censer for whoever comes through here after us.", tag = 6, id = "take" },
        { "character_rowan", "Now let's keep moving. There's more of this quarter to clear.", tag = 7, id = "leave" },
    },
}
