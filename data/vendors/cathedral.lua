-- Priest vendor. Its quest line hunts the corrupted and ends facing Lust.
return {
    name = "The Cathedral",
    class = "priest",
    -- THE SHOPKEEPER'S FACE. Read by the shop's keeper pane (ui/panels/shop.lua) and by any
    -- scene this house speaks in. A vendor is its own person, not the companion its line earns:
    -- see Shop:drawKeeper for the version where the two were one and why it was reversed.
    portrait = "assets/portraits/cathedral.png",
    description = "Cold stone and colder certainty. The faithful arm those who purge.",
    sin = "lust",
    -- The companion this house's line earns; see data/vendors/bastion.lua for why it is authored here.
    companion = "character_amana",
}
