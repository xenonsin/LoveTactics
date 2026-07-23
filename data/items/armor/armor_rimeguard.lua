-- Rimeguard: a coat of frozen mail. Enemies standing next to its wearer are Crippled -- slowed to a
-- crawl -- and allies feel nothing (data/hazards/hazard_rimeguard.lua).
--
-- THE PUREST AREA DENIAL IN THE GAME, and the point of it is that it deals NOTHING. A damage aura
-- makes standing near you expensive, which an enemy answers by taking the damage and killing you
-- anyway. A movement aura makes standing near you SLOW, which an enemy cannot answer at all except by
-- not being there -- and "not being there" is the entire job of the knight who wears it. The coat
-- turns its wearer into terrain.
--
-- Sided, so the party's own skirmishers work freely through the same tiles the enemy is bogged down
-- in. That asymmetry is what lets a Rimeguard knight anchor a doorway while the rogue slips past them
-- both ways -- which is the shape of a good defensive turn in this game and was previously very hard
-- to build without spending the knight's whole turn on Defend.
--
-- Cripple rather than Mired, deliberately: Mired doubles ability costs as well as movement, which
-- would make this a caster-hate item worn by a class that already has three. Cripple takes only the
-- legs, so what the coat denies is exactly one thing -- the ability to leave, or to arrive.
--
-- No active, no cost. The knight walks somewhere and stands there, which is the class's whole thesis
-- rendered as an item.
return {
    name = "Rimeguard",
    description = "Enemies standing beside its wearer are slowed to a crawl.",
    flavor = "It was never thawed. The Bastion's quartermaster is very clear that it was never frozen either.",
    sprite = "assets/items/armor_rimeguard.png",
    type = "armor",
    tags = { "heavy", "ice" },
    class = "knight",
    price = 400,
    repRank = 4,
    incense = { hazard = "hazard_rimeguard", radius = 1 },
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
    resist = { ice = 4 }, -- the wearer, at least, is used to it
}
