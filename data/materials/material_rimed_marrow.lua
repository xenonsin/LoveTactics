-- APEX TROPHY: what the Bastion's deep bodies pay for being put down a second time.
--
-- THE THIRD FAMILY OF STOCK, and the reason it is a family rather than another house stock: a house
-- stock carries a `class` and models/material.lua indexes those by it, so a second material claiming
-- `knight` would alias the one already there. This carries `house` instead -- the vendor, not the class
-- -- and models/material.lua's Material.isTrophy is what tells the two apart.
--
-- WHAT IT IS FOR. A bounty names one piece and pays it the first time that body goes down
-- (models/bounty.lua). Every kill after that pays THIS instead, and the Forge demands it for the deep
-- rungs of this house's gear (models/forge.lua's materialsFor). That is Monster Hunter's actual loop --
-- the rare thing you want once, and the parts you farm forever -- expressed in the material layer,
-- because a drop here is a whole item and a second copy of a sword you own is worth nothing.
--
-- Dropped by Acedia, the Unrelieved and by the lieutenant that stands below her, the general paying
-- the larger share (models/bounty.lua's TROPHY_BY_TIER).
--
-- THE NAME AND THE LINE WANT THE AUTHOR'S EYE. The mechanism is settled and the register is copied from
-- the seven house stocks beside it -- a concrete trade noun, plainly described -- but these seven were
-- written by the pass that built the system rather than by the person who writes this game's words.
return {
    name = "Rimed Marrow",
    description = "Bone from a post that never stood down. Cold all the way through, and it does not thaw.",
    sprite = "assets/materials/rimed_marrow.png",

    -- The HOUSE, not the class. See the header.
    house = "bastion",

    -- Above mythril, because it is not bought, found or dug -- it only ever comes off a body that was
    -- standing at the end of a posting somebody chose to take.
    tier = 4,
}
