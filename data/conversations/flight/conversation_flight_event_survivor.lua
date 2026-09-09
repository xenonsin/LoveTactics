-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Stop 4 of the city sweep (states/prologue.lua's FLIGHT_QUEST), and the leg's second CHOICE. She is
-- one of the survivors the errand named, found under a collapsed block rather than in a wood: Act 0
-- happens inside the capital now.
--
-- THE MECHANIC THIS STOP TEACHES IS THE ADJACENCY GATE, AND IT IS ON BOTH BRANCHES ON PURPOSE.
-- Mark Target declares `requiresAdjacent = { type = "weapon", tag = "ranged" }`: it is dead in the grid
-- unless a ranged weapon touches it, the combat panel names what is missing in a red broken-link badge,
-- and the loadout lights the cells that would fix it green (Combat.adjacencyCandidateCells). The bow
-- from stop 1 is the only answer in the bag, which is why this stop comes after that one.
--
-- It used to sit on ONE branch, against the Assayer's Eye on the other, and that was the flaw: half of
-- everyone who played the prologue met the hard half of the grid and half never did. A lesson decided by
-- a coin flip is not a lesson. So the tell is what she gives either way -- she is an apothecary who has
-- just been dug out of a wall, and she is grateful in both directions.
--
-- THE BRANCH STILL HAS A STAKE; it is simply no longer the mechanic. Take her purse or leave her your
-- supplies and take her lens: coin now against a tool, priced near enough to even (the Eye lists at 80).
-- Compare the shrine at stop 2, where the TRADE is the point and the item on each side differs. Neither
-- entry here is a ladder rung -- the ladder is Mark Target, and this is what rides beside it.
--
-- BOTH branches set `met_the_survivor`, so the flag says she was met and never which way it went.
-- tests/story_effect_spec.lua pins the effects; states/prologue.lua's SCENE_GIFTS hands the mark over
-- when Act 0 is skipped, which is why THAT is the id named there.
--
-- ROWAN POINTS AT THE GRID WITHOUT NAMING IT -- "keep it beside the bow" is a thing you do with a
-- quiver in her mouth and the rule itself on the loadout screen. "Cell" and "grid" belong to the coach
-- bubbles (data/conversations/tutorial/conversation_tutorial_flight.lua), not to her.
--
-- Both branches goto `part`, which is the line that ends the stop. Keep that shape.
--
-- ROWAN SPEAKS IT ALL. The avatar is silent for the whole of Act 0 as it currently stands.
return {
    title = "A Voice in the Rubble",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "Hold. Someone's under that wall, hurt and trying not to make a sound.", tag = 1 },
        { "character_rowan", "Easy. We're not with the things that did this.", tag = 2 },
        { "character_rowan", "She's an apothecary, and she's already telling us the trick of them: mark one before you strike and you'll see where its guard runs thin. Keep that beside the bow and it'll work.", tag = 8 },
        { "character_rowan", "She's got a purse she can't spend and a lens she can't carry. We can take the coin, or leave her our rations and take the glass. Choose...", tag = 9, choices = {
            { "Take the purse.", tag = 3, goto = "ask", effect = { grant = "ability_mark_target", gold = 60, flag = "met_the_survivor" } },
            { "Share what we're carrying, and take the lens.", tag = 4, goto = "give", effect = { grant = { "ability_mark_target", "ability_assayers_eye" }, flag = "met_the_survivor" } },
        } },
        { "character_rowan", "She pressed it on us and wouldn't hear otherwise. Said coin buys nothing in a quarter with no one left to sell.", tag = 5, id = "ask", goto = "part" },
        { "character_rowan", "Not much to spare, and she took it kindly. Look through that lens and a demon's satchel keeps nothing back.", tag = 6, id = "give" },
        { "character_rowan", "An apothecary, before all this. She can make the square on her own now. Let's keep clearing, {name}.", tag = 7, id = "part" },
    },
}
