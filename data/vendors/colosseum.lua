-- Fighter vendor. Its quest line runs through the arena and ends facing Wrath.
return {
    name = "The Colosseum",
    class = "fighter",
    portrait = "assets/portraits/colosseum.png", -- large VN portrait for conversations (falls back if missing)
    description = "Blood, sand, and a roaring crowd. The masters here sell what wins fights.",
    sin = "wrath",
    -- The companion this house's line earns; see data/vendors/bastion.lua for why it is authored here.
    companion = "character_saber",
}
