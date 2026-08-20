-- Arcane Conduit: the mage half of the Battlemage (fighter x mage). Items sitting next to it in your
-- 3x3 grid cast half again as hard, and each such cast spends a point of banked Arcane.
--
-- The author's own idea, and the one item in the whole pass that opened something new: it is the first
-- AURA IN THE GAME THAT COSTS SOMETHING. The `aura` block has always let a charm reshape its neighbours
-- -- amountBonus, rangeBonus, twin, careful -- and all of it has always been free once bought, which
-- made grid position a layout puzzle you solve once. This makes it a spending decision, because the
-- conduit can only sharpen as many casts as you have banked.
--
-- Arcane banks off the `cast` tally, so the battlemage's own spellcasting funds the escalation. Cast to
-- charge, then spend the charge on a bigger cast: the loop is the discipline, and it is the reason this
-- replaced a spend-it-all-for-big-damage draft the author turned down as too common.
--
-- Adjacency is the real price. Nine cells, eight neighbours, and the cell holding the conduit contributes
-- no damage of its own -- so a battlemage running it in the centre is trading a slot for the shape.
return {
    name = "Arcane Conduit",
    description = "Grid neighbours cast half again as hard, spending a point of Arcane each time. Casting banks Arcane.",
    flavor = "Everything in the case is wired to everything else. He insists this is normal.",
    sprite = "assets/items/utility_arcane_conduit.png",
    type = "utility",
    tags = { "charm", "magical" },
    class = "mage",
    discipline = "battlemage",
    price = 210,
    unlockQuests = 1,
    charge = { key = "arcane", from = { "cast" }, max = 5 },
    traits = { "trait_arcane_conduit" },
}
