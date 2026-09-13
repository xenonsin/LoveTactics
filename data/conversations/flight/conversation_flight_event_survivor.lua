-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Stop 4 of the city sweep (states/prologue.lua's FLIGHT_QUEST), and the leg's second CHOICE. She is
-- one of the survivors the errand named, found under a collapsed block rather than in a wood: Act 0
-- happens inside the capital now.
--
-- WHAT IS ON THE TABLE IS THE MARK AGAINST HER PURSE. Mark Target declares
-- `requiresAdjacent = { type = "weapon", tag = "ranged" }`: it is dead in the grid unless a ranged
-- weapon touches it, the combat panel names what is missing in a red broken-link badge, and the
-- loadout lights the cells that would fix it green (Combat.adjacencyCandidateCells). The bow from
-- stop 1 is the only answer in the bag, which is why this stop comes after that one -- but a company
-- that takes the coin never meets that rule here, and that is the price of the coin.
--
-- She has nothing else to give. The lens she used to carry (the Assayer's Eye) is off this stop
-- entirely; it is alchemist's shelf stock now, bought in the city like any other ability. Compare the
-- shrine at stop 2, where the TRADE is the point and the item on each side differs. Here one side is
-- a thing you can spend and the other is a thing you can only be taught.
--
-- BOTH branches set `met_the_survivor`, so the flag says she was met and never which way it went.
-- tests/story_effect_spec.lua pins the effects; states/prologue.lua's SCENE_GIFTS hands the mark over
-- when Act 0 is skipped, which is why THAT is the id named there -- a skip takes the taught branch.
--
-- ROWAN POINTS AT THE GRID WITHOUT NAMING IT -- "keep it beside the bow" is a thing you do with a
-- quiver in her mouth and the rule itself on the loadout screen. "Cell" and "grid" belong to the coach
-- bubbles (data/conversations/tutorial/conversation_tutorial_flight.lua), not to her.
--
-- Both branches reach `part`, which is the line that ends the stop. Keep that shape.
--
-- ROWAN SPEAKS IT ALL. The avatar is silent for the whole of Act 0 as it currently stands.
return {
    title = "A Voice in the Rubble",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "Hold. Someone's under that wall, hurt and trying not to make a sound.", tag = 1 },
        { "character_rowan", "Easy. We're not with the things that did this.", tag = 2 },
        { "character_rowan", "She's an apothecary. She's got a purse she can't spend down here, and she's got the trick of these things in her head. She'll give us the one or the other. Choose...", tag = 9, choices = {
            { "Take the purse.", tag = 3, goto = "ask", effect = { gold = 60, flag = "met_the_survivor" } },
            { "Share what we're carrying, and hear her out.", tag = 4, goto = "give", effect = { grant = "ability_mark_target", flag = "met_the_survivor" } },
        } },
        { "character_rowan", "She pressed it on us and wouldn't hear otherwise. Said coin buys nothing in a quarter with no one left to sell.", tag = 5, id = "ask", goto = "part" },
        { "character_rowan", "Not much to spare, and she took it kindly. Then she told us how they're put together.", tag = 6, id = "give" },
        { "character_rowan", "Mark one before you strike and you'll see where its guard runs thin. Keep that beside the bow and it'll work.", tag = 8 },
        { "character_rowan", "An apothecary, before all this. She can make the square on her own now. Let's keep clearing, {name}.", tag = 7, id = "part" },
    },
}
