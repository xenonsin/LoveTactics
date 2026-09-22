-- THE CLOSE HERD: the rule. The middle of the Ancient Stag's three, and the one that is a thing you
-- LEARNED from the fight rather than a thing you cut off the body.
--
-- It grants data/traits/trait_herd_warmth.lua -- the animal's own rule, unchanged: while at least one
-- ally stands orthogonally beside you, you heal a little every tick, and standing alone you heal
-- nothing. That is exactly the split utility_feral_instinct and the Reprisal Quiver already are, and
-- for the reason that split exists: a body part cannot be looted, but a RULE can be learned. Nobody
-- carries a stag's herd home. Anybody can work out what it was doing.
--
-- IT FILLS THE HOLE IN AN ADJACENCY FAMILY. Two charms already pay for a closed line and both pay in
-- stats -- trait_formation_fighter in defense, trait_close_ranks in damage -- so a formation was
-- already a thing that survived and threatened, and was not yet a thing that KEPT. This is the third
-- corner, and it is the one that changes what a fight costs rather than what a turn does: every point
-- it returns is a point the Ward does not charge for and a trip that ends one fight later.
--
-- THE RATE IS THE PRIEST'S (Combat.HERD_WARMTH_HEAL == Combat.SANCTIFY_HEAL), and the two are not
-- competing. A Sanctified Presence radiates outward and wards the whole line off one body, so a
-- company fields one priest and four people get it. This pays only its bearer, so a company that wants
-- four of these has spent four charm cells on it. Same number per tick, wildly different price, and
-- that is the whole of what separates a discipline from a habit.
--
-- WHY THE SENTINEL'S SHELF. data/items/utility/utility_held_line.lua is already there and is already
-- the "do not break the line" charm; this is the reward for having kept it. `class` is the vendor
-- shelf and never an equip gate -- anyone may carry it (docs/classes.md).
--
-- AND IT IS A REAL DECISION IN A SKIRMISH LINE, not a free upside. It pays nothing to a scout, an
-- archer holding the back corner, or anyone the fight has pulled out of position -- which is most of
-- the bodies that most want the health. What it rewards is the company that already decided to fight
-- shoulder to shoulder, which is the same company the two charms above are built for and the same
-- company a three-wide antler sweep is built to punish. The stag taught both halves.
--
-- RIFT-ONLY (`unstocked`). It comes off the body and nowhere else: no counter deals one however many
-- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
return {
    name = "The Close Herd",
    description = "Recovers health each tick while at least one ally stands beside you.",
    flavor = "The hunter's whole report was four lines long. Three of them were about how they stood.",
    sprite = "assets/items/utility_the_close_herd.png",
    type = "utility",
    tags = { "charm", "nature" },
    class = "sentinel",
    -- The second of three by depth (docs/drops.md): the hide is the print you meet, this is the rule,
    -- and the Lowered Crown is the one you are still after.
    unlockLevel = 4,
    unstocked = true,
    traits = { "trait_herd_warmth" },
}
