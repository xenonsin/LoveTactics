-- Hunter vendor. Its quest line fells sacred beasts and ends facing Gluttony.
return {
    name = "Hunter's Lodge",
    class = "hunter",
    -- THE SHOPKEEPER'S FACE. Read by the shop's keeper pane (ui/panels/shop.lua) and by any
    -- scene this house speaks in. A vendor is its own person, not the companion its line earns:
    -- see Shop:drawKeeper for the version where the two were one and why it was reversed.
    portrait = "assets/portraits/hunters_lodge.png",
    description = "Antlers on every beam. They ask what you killed before they ask your name.",
    sin = "gluttony",
    -- The companion this house's line earns; see data/vendors/bastion.lua for why it is authored here.
    companion = "character_kaya",
}
