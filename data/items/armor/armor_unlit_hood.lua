-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Struck and still standing, the wearer slips out of sight until its next turn (trait_vanishing_act).
-- Being hit is how you disappear, which inverts the usual defensive bargain: every other piece of
-- armour is worth less the more it is used, and this one only ever starts working once somebody has
-- already committed to killing you.
--
-- status_invisible means enemies cannot TARGET the wearer at all until its turn comes round -- so a
-- focused rogue eats one blow and then the rest of the enemy line has to find something else to do
-- with its turn. Against a single attacker it is a full stop; against an AoE it is nothing, because
-- an area cast never had to target anybody.
--
-- Cloth, so it costs a square of pace -- and the hood is the one item on this shelf that does not mind,
-- since the turn it buys back is spent standing somewhere nobody is looking.
return {
    name = "The Unlit Hood",
    description = "Struck and still standing, slip out of sight until your next turn.",
    flavor = "The Undercroft's oldest joke is that it was never dyed black. Nothing was ever done to it at all.",
    sprite = "assets/items/armor_unlit_hood.png",
    type = "armor",
    tags = { "cloth" },
    class = "rogue",
    traits = { "trait_vanishing_act" },
    bonus = { defense = { 2, 2, 3, 3, 4, 4, 4, 5, 5, 6, 6 }, movement = -1 },
}
