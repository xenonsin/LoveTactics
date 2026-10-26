-- Hunter -- a ROOT class (gluttony's house). See data/classes/knight.lua for what a root is and why
-- the blurb moved off Item.CLASSES.
return {
    name    = "Hunter",
    description = "Sets a target up, then takes it. Marks, traps and crippling shots soften a foe, and "
        .. "most of the kit needs a bow sitting beside it in the grid.",
    exemplar = "character_kaya", -- the companion the Hunter's Lodge posts
    -- The class crest on the Classes tab (ui/class_editor.lua); until drawn, its house's mark stands in.
    crest = "assets/classes/hunter.png",
}
