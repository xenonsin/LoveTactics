-- Assets that deliberately draw ONE silhouette, told apart by COLOUR alone.
--
-- Everything else in this pipeline goes the other way. `. icon-map` keeps a claim ledger so no two
-- assets may hold the same game-icons slug, tools/icon_compose.lua leads with that map because it is
-- "the only channel that identifies an item", and tests/art_pipeline_spec.lua reddens on a collision.
-- The rule is right: 850 items that resolve to 62 shapes is a catalogue nobody can read.
--
-- It is wrong for a SET, though -- a handful of wares that are the same object and differ in exactly
-- one property. The pool potions are the case that named this file. A Healing Potion and a Mana Potion
-- are one flask; what the player must read off the slot is WHICH POOL it fills, and a second
-- silhouette says that worse than the colour does, because the colour is the one the HP/MP/SP bars
-- have already taught them (ui/panels/consumables.lua's BAR_COLOR, which the tints below are lifted
-- from unchanged).
--
-- A set is a DECLARATION and the most specific thing anyone has said about these assets, so it wins
-- over every channel including the map: `Icon.baseFor` and `Icon.tintFor` read it first, `. icon-map`
-- seeds the claim ledger with it so a re-run cannot quietly break the pairing back apart, and the
-- uniqueness spec exempts a clash whose two halves are in one set (and then asserts they differ in
-- colour, which is the whole promise).
--
-- Keep sets RARE and keep them small: one object, one axis, colours far enough apart to read at slot
-- size. A set is not a way to duck the mapper -- if two items are different things, they get different
-- pictures.
--
--   icon     the shared silhouette (a game-icons slug, or an art/bases/ replacement of one)
--   members  sprite key (the path with "assets/" stripped, same key the map uses) -> tint hex
return {
    {
        icon = "lorc/standing-potion",
        members = {
            ["items/potion.png"]      = "#c75257", -- health -- the warm red of the HP bar
            ["items/mana_potion.png"] = "#5c8feb", -- mana   -- the cool blue of the MP bar
        },
    },
}
