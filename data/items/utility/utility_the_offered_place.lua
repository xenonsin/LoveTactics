-- THE OFFERED PLACE: what a company carries out of the succubus line, and it is the kiss handed over.
--
-- She spends her fight deciding that the body which reached her is the body standing somewhere else
-- (data/items/weapon/weapon_parting_kiss.lua). This is that, on the player's own swings: every melee
-- blow you land trades tiles with what it hit. See data/traits/trait_the_offered_place.lua for why it
-- is melee only and what the trade costs.
--
-- IT IS THE ONLY WAY THROUGH A LINE IN THE GAME. The trade itself is sold twice -- the rogue's Swap and
-- the Ninja's Shadow Trade -- and both are CASTS that spend the turn you would otherwise have hit with.
-- On a swing it is a different item: you cut the body holding the doorway and finish the blow behind
-- it. What you have bought is a step past the front rank; what you have paid is that you are now alone
-- on the wrong side of it.
--
-- `class` IS THE VENDOR SHELF AND NEVER AN EQUIP GATE (docs/classes.md). The Assassin is where getting
-- to the body BEHIND the line is already the whole discipline -- "kills one target and leaves" -- not
-- who is allowed to carry it. On a Vanguard it is a very different and perfectly legal item.
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "The Offered Place",
    description = "Your melee blows trade places with what they hit.",
    flavor = "She is unfailingly generous about where she is standing. It is the only thing she gives away.",
    sprite = "assets/items/the_offered_place.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "assassin",
    unlockLevel = 6,
    traits = { "trait_the_offered_place" },
}
