-- Mage vendor. Its quest line chases forbidden knowledge and ends facing Pride.
return {
    name = "The Arcanum",
    class = "mage",
    -- THE SHOPKEEPER'S FACE. Read by the shop's keeper pane (ui/panels/shop.lua) and by any
    -- scene this house speaks in. A vendor is its own person, not the companion its line earns:
    -- see Shop:drawKeeper for the version where the two were one and why it was reversed.
    portrait = "assets/portraits/arcanum.png",
    description = "A library that has outlived every scholar who swore he could read it safely.",
    sin = "pride",
    -- The companion this house's line earns; see data/vendors/bastion.lua for why it is authored here.
    companion = "character_gyeom",
}
