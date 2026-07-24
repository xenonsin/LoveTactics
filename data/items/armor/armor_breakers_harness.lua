-- Breaker's Harness: the Vanguard (knight x rogue) rewarding aim rather than force. A shove that ends
-- against a wall, a body, or the edge of the field Stuns whatever it slammed.
--
-- The condition is the item. Combat.knockback already hurts a stopped shove harder the more travel it
-- was denied -- the momentum has to go somewhere -- and this reads the same moment and takes a turn
-- instead of a bruise. Nothing about it fires in open ground, so the harness is worth exactly as much
-- as the wielder's willingness to look at the map before pushing.
--
-- Heavy plate, and it pays the tier (-2 movement, docs/classes.md). A Vanguard is slow. It has to be:
-- the whole kit is about deciding where somebody else stands, and a discipline that could also outrun
-- them would not be a breach, it would be a chase.
return {
    name = "Breaker's Harness",
    description = "A shove that slams into a wall or a body Stuns what it hit.",
    flavor = "Half the wall is doing the work. He only ever intended to supply the other half.",
    sprite = "assets/items/armor_breakers_harness.png",
    type = "armor",
    tags = { "heavy" },
    class = "knight",
    discipline = "vanguard",
    price = 440,
    repRank = 3,
    bonus = { defense = { 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11 }, movement = -2 },
    traits = { "trait_breakers_harness" },
}
