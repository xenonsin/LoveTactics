-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The overworld coach's words, all of them, in one file so a translator has one place to work.
-- states/game.lua fields them: the fixed chain, move -> loadout -> equip, and nothing else.
--
-- THE COACH IS WHERE "click", "cell" AND "beside" ARE ALLOWED TO LIVE. Rowan's own lines are pure
-- fiction -- she is a knight in a burning capital and she does not know what a mouse is
-- (data/tutorials/village.lua carries the full argument for the split). These are the interface's
-- voice, not hers, which is why they can name the grid outright where her spoken lines only ever point
-- at it sideways ("keep it next to whatever you mean to swing").
--
-- THE MECHANIC BUBBLES ARE GONE. There used to be three more lines here, one per item that landed with
-- nobody speaking -- the buckler's stance swap, the fire coat's typed mitigation, the charm with no
-- button. Each of them explained a rule the item's own tooltip and the grid already state, so what they
-- actually did was cover the stash with words at the moment the player wanted to look at it. The chain
-- above stays because it is a door: those three steps are the only ones holding the road shut.
return {
    title = "The Open Road",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "Walk to the chest ahead. Use WASD, the arrow keys, or click a tile.", tag = 1, id = "move_hint" },
        { "character_rowan", "Open your loadout to see what you found.", tag = 2, id = "loadout_hint" },
        { "character_rowan", "{select} an item in your stash to equip it to a hero.", tag = 3, id = "equip_hint" },
    },
}
