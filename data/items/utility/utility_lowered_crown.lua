-- THE LOWERED CROWN: the chase. The deepest of the Ancient Stag's three, and the only one that is the
-- animal's actual reflex rather than its hide or its habit.
--
-- It grants data/traits/trait_antler_toss.lua, which is what the stag answers with: strike it from an
-- adjacent tile and the head comes up under you and you are a tile further away, paying for whatever
-- you came down on. The rack itself is creature kit and can never be looted (weapon_stag_antlers,
-- `noSteal`) -- this is the rack rebuilt as a thing a person straps on, the same way the Swailing
-- Brand is the Vengeful Spirit's own cast rebuilt at a price.
--
-- READ IT AGAINST THE BULWARK SHIELD, because that is the honest comparison and the differences are
-- the item:
--
--   armor_bulwark_shield   Shield Shove -- TWO tiles, answers an answer as readily as an attack, and
--                          costs the ARMOUR slot, so its bearer is in a shield and not in a coat.
--   this                   Antler Toss  -- ONE tile, answers an attack only, and costs a CHARM cell,
--                          so it rides a body already wearing whatever plate it likes.
--
-- Shorter, fussier and wearable alongside real armour. That is not a strictly-worse shield and it is
-- not a strictly-better one; it is the shove arriving in the slot where a heavy line has actually got
-- room, which is the thing the shield could never be. A knight in full plate has never once been able
-- to make people stop standing next to him.
--
-- THE DEEPEST OF THE THREE BECAUSE IT IS THE ONE THAT CHANGES A BOARD. The hide is a number and the
-- Close Herd is a slow one; this moves bodies, and moving bodies is how this game's best items pay --
-- into a wall, into a fire, into a spike trap, into the next foe in the rank. Depth is rarity
-- (docs/drops.md), so the ORDER of the three numbers is the drop-rate design and this is the end of it.
--
-- RIFT-ONLY (`unstocked`). It comes off the body and nowhere else: no counter deals one however many
-- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
return {
    name = "The Lowered Crown",
    description = "Struck in melee, you throw the attacker back a tile. A collision hurts them.",
    flavor = "It is not a charge. A charge is what a boar does. This is a lift, and it is worse.",
    sprite = "assets/items/utility_lowered_crown.png",
    type = "utility",
    tags = { "charm", "nature" },
    class = "vanguard",
    -- The last of three by depth (docs/drops.md): the hide is the print you meet, the Close Herd is
    -- the rule, and this is the one you are still after.
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_antler_toss" },
}
