-- THE CONGREGATION: what a company carries out of the Lady Chapel, and it is the Abbess's own hiding
-- place -- a wound meant for you opening in the bodies you have taken instead.
--
-- HALF OF A PAIR, AND THE PLAYER BRINGS THE OTHER HALF. On a body with no way to Charm this is a blank
-- cell, deliberately and exactly as Coalsong is on a body with no taunt. An item that shipped its own
-- charm would be the Undercroft's ladder in one grid slot; what this hands over is the PAYOFF, so it
-- fires on whatever charm the company already owns and never on one it does not.
--
-- AND THE OTHER HALF FALLS OFF THE SAME LINE, which is what makes the pair findable without a counter
-- having to point at it. ability_charm is `unstocked` now -- no shop deals one in either direction --
-- and the succubi hand it over when they fall, so a company that walks out of a Lust floor with both
-- has been taught a rule in two halves by the bodies that used both halves on it. That is the shape
-- the coils already have one floor over: The Slow Circle puts a body in a hold, Constrictor's Due
-- bills it, and neither is worth much without a way to get the other.
--
-- `class` IS THE VENDOR SHELF AND NEVER AN EQUIP GATE (docs/classes.md). The Thief is where taking a
-- body is written down, so it is where this is graded and where a counter racks it once the ladder has
-- climbed -- not who is allowed to carry it.
--
-- IT IS ALSO THE ANSWER TO CHARM'S OLDEST COMPLAINT. A turned foe is two turns of a body swinging at
-- its own line and then it comes back, and against a single strong enemy that has never been worth the
-- cast. With this in the grid the turned body is also a wall: every blow aimed at you lands on it
-- instead, whole, split among however many you are holding. Charm stops being disruption and becomes
-- mitigation, which is a build rather than a trick.
--
-- AND IT CUTS BOTH WAYS, which is the price and is left in. The shares are re-thrown as real blows
-- through Combat.dealFlatDamage, so a charmed body you were planning to keep is a body you are
-- personally killing every time somebody swings at you -- and a turned foe that falls is a foe you no
-- longer get to turn. The bill comes due the moment the charm lapses, too: it is a ward with somebody
-- else's clock on it.
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "The Congregation",
    description = "Damage dealt to you is split among the foes you have Charmed.",
    flavor = "A saint is not a woman who is never struck. A saint is a woman who has somewhere to put it.",
    sprite = "assets/items/the_congregation.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "thief",
    unlockLevel = 7,
    traits = { "trait_the_congregation" },
}
