-- Knight vendor. Its quest line is duty kept under pressure, and ends facing Sloth --
-- which is not laziness but dereliction: the oath abandoned.
return {
    name = "The Bastion",
    class = "knight",
    -- THE SHOPKEEPER'S FACE. Read by the shop's keeper pane (ui/panels/shop.lua) and by any
    -- scene this house speaks in. A vendor is its own person, not the companion its line earns:
    -- see Shop:drawKeeper for the version where the two were one and why it was reversed.
    portrait = "assets/portraits/bastion.png",
    description = "An order that measures a knight by what they refused to abandon.",
    sin = "sloth",
    -- The companion this house's line earns. Authored here rather than derived: the pairing is a design
    -- fact (docs/story.md -- a general and her foil are the same wound with two answers) stated nowhere
    -- else in data. models/vendor_visit.lua reads it to join this house's companion at its counter, the
    -- first time the player walks in having run its errand. Rowan is the Bastion's even though the
    -- prologue hands her over rather than this house's posting.
    companion = "character_rowan",
}
