-- COALSONG: what a company carries out of the Eyrie, and it is the Matriarch's cry factored into its
-- parts.
--
-- She lands Taunt and Burn in one breath and the couple is the Lust circle's whole sentence about
-- fire -- you are compelled to come, and the coming is what costs you
-- (data/items/weapon/weapon_the_wanting.lua). What is handed over here is the COUPLING, not the cast:
-- whatever the bearer's own taunt catches, catches fire. See data/traits/trait_coalsong.lua.
--
-- WHICH MAKES IT A DEAD CHARM ON A BODY WITH NO TAUNT, deliberately. It is half of a pair and the
-- player brings the other half; an item that shipped its own taunt would be the Champion's ladder in
-- one cell.
--
-- `class` IS THE VENDOR SHELF AND NEVER AN EQUIP GATE (docs/classes.md). It shelves at the Champion
-- because that is where the taunts are and a payoff you cannot find is a payoff nobody assembles --
-- not because a Champion is who may wear it.
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "Coalsong",
    description = "Foes you taunt catch fire.",
    flavor = "She does not sing at anybody. She sings, and the wanting is what you brought yourself.",
    sprite = "assets/items/coalsong.png",
    type = "utility",
    tags = { "charm", "fire" },
    class = "champion",
    unlockLevel = 6,
    traits = { "trait_coalsong" },
}
