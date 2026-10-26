-- Fighter -- a ROOT class (wrath's house). See data/classes/knight.lua for what a root is and why
-- the blurb moved off Item.CLASSES.
return {
    name    = "Fighter",
    description = "Trades health and tempo for damage. Heavy axes and hammers sweep the tiles in front of "
        .. "you, stun what they hit, and cost you something to swing.",
    exemplar = "character_saber", -- the companion the Colosseum posts
    -- The class crest on the Classes tab (ui/class_editor.lua); until drawn, its house's mark stands in.
    crest = "assets/classes/fighter.png",
}
