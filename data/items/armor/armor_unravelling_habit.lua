-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Carries a square of Unravelling ground (`incense`, Combat.layIncense): everything standing in it
-- takes more from every magical hit (status_unravelled).
--
-- The mage's answer to armor_muster_cuirass, and it is worth reading the two side by side because they
-- are the same idea aimed at different loadouts. The knight's cuirass amplifies `pierce` and therefore
-- doubles in value in a company of spears; this amplifies the whole magical SCHOOL, so it is worth
-- roughly nothing beside a line of axes and enormous beside two casters and a censer.
--
-- Which makes it the first mage item that is an argument about what everyone else brought, rather than
-- about what the mage can do. Pride's item, delivered as a claim on the party's composition.
--
-- UNSIDED, unlike the cuirass -- hazard_unravelling has no ally check, so the wearer is standing in
-- their own weakness and so is anyone protecting them. Against an enemy Arcanum this is close to
-- suicide, and that asymmetry is the price of an effect that would otherwise be strictly better than
-- the knight's.
--
-- Cloth: a square of pace, and the wearer wants to be much closer to the enemy than a caster likes.
return {
    name = "Unravelling Habit",
    description = "Carries picked-loose ground with you: everything standing in it takes more from magic.",
    flavor = "The Arcanum's weavers unmake it a thread at a time and insist that this is the finished state.",
    sprite = "assets/items/armor_unravelling_habit.png",
    type = "armor",
    tags = { "cloth", "arcane" },
    class = "mage",
    incense = { hazard = "hazard_unravelling", radius = 1 },
    bonus = { magicDefense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, movement = -1 },
}
