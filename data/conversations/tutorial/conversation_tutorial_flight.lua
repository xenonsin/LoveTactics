-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The overworld coach's words, all of them, in one file so a translator has one place to work.
-- states/game.lua fields them: the first three are the fixed chain (move -> loadout -> equip), the
-- last three are the MECHANIC bubbles, owed by an item rather than by a step and drawn over the stash
-- the item landed in (game.drawCoachLesson, keyed off FLIGHT_LESSONS).
--
-- THE COACH IS WHERE "click", "cell" AND "beside" ARE ALLOWED TO LIVE. Rowan's own lines are pure
-- fiction -- she is a knight in a burning capital and she does not know what a mouse is
-- (data/tutorials/village.lua carries the full argument for the split). These are the interface's
-- voice, not hers, which is why they can name the grid outright where her spoken lines only ever point
-- at it sideways ("keep it next to whatever you mean to swing").
--
-- Each mechanic line says WHAT THE RULE IS, not what the item is worth. The tooltip already carries the
-- numbers and the description; what a bubble is for is the rule a player would otherwise have to
-- discover by finding the item dead in a cell.
return {
    title = "The Open Road",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "Walk to the chest ahead. Use WASD, the arrow keys, or click a tile.", tag = 1, id = "move_hint" },
        { "character_rowan", "Open your loadout to see what you found.", tag = 2, id = "loadout_hint" },
        { "character_rowan", "{select} an item in your stash to equip it to a hero.", tag = 3, id = "equip_hint" },
        { "character_rowan", "A shield changes what Wait does: end the turn braced instead of idle.", tag = 4, id = "stance_hint" },
        { "character_rowan", "Armor answers a kind of damage. This one drinks fire, and nothing else.", tag = 5, id = "typed_hint" },
        { "character_rowan", "This one has no action to press. It sits in a cell and works on its own.", tag = 6, id = "passive_hint" },
    },
}
