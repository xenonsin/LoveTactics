-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The overworld coach's words, all of them, in one file so a translator has one place to work.
-- states/game.lua fields them: the fixed chain, move -> loadout -> equip, and nothing else.
--
-- THE MOVE STEP IS THREE LINES, because it is the only one in the game's first minute that names
-- HARDWARE. It named WASD, the arrow keys and a click in one breath -- three controls a handset does
-- not have and two a pad does not -- so the opening bubble of the prologue was pointing at a keyboard
-- nobody was necessarily holding. states/game.lua's moveHintId picks between the three through
-- InputMode.pick, the same three-way answer the HUD hint under the bubble already gave.
--
-- Whole sentences rather than a {select}-style token, and that is the device's doing rather than the
-- translator's: a movement instruction is not a verb swap. The pointer branch wants BOTH its routes
-- named, the finger wants its own two (tap a tile to walk there, swipe to take one step --
-- ui/overworld_map.lua), and a pad wants neither. Authored HERE rather than in models/locale.lua
-- beside SELECT_WORD for the reason every hint bag exists: a line welded into a state or a model is
-- English forever (docs/localization.md).
--
-- The two new ids sort after the chain's tags because extract_strings stamps in first-seen order, and
-- a tag is stable once stamped -- the walking order is the `id` list in states/game.lua, never this.
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
-- (Two of the three gifts those lines were written for are themselves gone now -- the buckler and the
-- charm both taught rules the party's own starting kit had been drawing since the first fight, so the
-- stops that handed them over were re-cut; see states/prologue.lua's FLIGHT_QUEST. The bubbles were
-- deleted first and for the same reason, which is the tell that the gifts were the real problem.)
return {
    title = "The Open Road",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "Walk to the chest ahead. Use WASD, the arrow keys, or click a tile.", tag = 1, id = "move_hint" },
        { "character_rowan", "Walk to the chest ahead. Use the d-pad or the left stick.", tag = 4, id = "move_hint_pad" },
        { "character_rowan", "Walk to the chest ahead. Tap it, or swipe to take one step.", tag = 5, id = "move_hint_touch" },
        { "character_rowan", "Open your loadout to see what you found.", tag = 2, id = "loadout_hint" },
        { "character_rowan", "{select} an item in your stash to equip it to a hero.", tag = 3, id = "equip_hint" },
    },
}
